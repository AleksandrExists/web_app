-- Таблица пользователей
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT auth.uid(),  -- Supabase user ID
    email VARCHAR(255) UNIQUE,
    username VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Справочник типов задач
DROP TABLE IF EXISTS _dict_types CASCADE;
CREATE TABLE _dict_types (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) NOT NULL UNIQUE
);

-- Добавление типов задач
INSERT INTO _dict_types
(name)
VALUES
    ('Цель'),
    ('Привычка');

-- Тип повторения привычек
DROP TYPE IF EXISTS interval_type CASCADE;
CREATE TYPE interval_type AS ENUM ('day', 'week', 'month', 'quarter', 'year');

-- Общая таблица для задач
DROP TABLE IF EXISTS items_base CASCADE;
CREATE TABLE items_base (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(64) NOT NULL,
    weight DECIMAL(5, 2),
    type_id INTEGER NOT NULL,
    begin_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,  -- Для goals обязателен, для habits опционален
    duration INTEGER GENERATED ALWAYS AS
        ((end_date - begin_date) + 1) STORED,
    allow_overcompletion BOOLEAN NOT NULL DEFAULT TRUE,
    target_value DECIMAL(10, 3) NOT NULL,

    -- Проверки
    CONSTRAINT valid_weight_check
        CHECK (weight IS NULL OR (weight >= 0 AND weight <= 100)),
    CONSTRAINT correct_date_check
        CHECK (end_date IS NULL OR end_date >= begin_date),

    -- Внешние ключи
    CONSTRAINT fk_item_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_item_type
        FOREIGN KEY (type_id)
        REFERENCES _dict_types(id)
        ON DELETE RESTRICT
);

-- Таблица целей
DROP TABLE IF EXISTS goals CASCADE;
CREATE TABLE goals (
    id INTEGER PRIMARY KEY REFERENCES items_base(id) ON DELETE CASCADE,
    add_to_sum BOOLEAN NOT NULL,
    start_value DECIMAL(10, 3),
    target_change DECIMAL(10, 3) GENERATED ALWAYS AS
        (target_value - COALESCE(start_value, 0)) STORED,
    CONSTRAINT end_date_required CHECK (
        EXISTS (SELECT 1 FROM items_base WHERE id = goals.id AND end_date IS NOT NULL)
    )
);

-- Таблица привычек
DROP TABLE IF EXISTS habits CASCADE;
CREATE TABLE habits (
    id INTEGER PRIMARY KEY REFERENCES items_base(id) ON DELETE CASCADE,
    negative BOOLEAN NOT NULL DEFAULT FALSE,
    interval_type interval_type NOT NULL,
    interval_length DECIMAL(10, 6) GENERATED ALWAYS AS (
        CASE interval_type
            WHEN 'day' THEN 1
            WHEN 'week' THEN 7
            WHEN 'month' THEN 30.436875
            WHEN 'quarter' THEN 91.310625
            WHEN 'year' THEN 365.2425
        END
    ) STORED
);

-- Таблица данных по дням
DROP TABLE IF EXISTS data CASCADE;
CREATE TABLE data (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date DATE NOT NULL,
    item_id INTEGER NOT NULL,
    value DECIMAL(10, 3),

    CONSTRAINT unique_date_item_id UNIQUE(date, item_id),
    CONSTRAINT fk_item
        FOREIGN KEY(item_id)
        REFERENCES items_base(id)
        ON DELETE CASCADE
);

-- Функции для расчета последнего не null значения в days
CREATE OR REPLACE FUNCTION last_non_null_state(
	state anyelement,
	value anyelement)
RETURNS anyelement
LANGUAGE plpgsql
AS $BODY$
BEGIN
    RETURN COALESCE(value, state);
END;
$BODY$;

CREATE OR REPLACE AGGREGATE last_non_null_value(anyelement) (
    SFUNC = last_non_null_state,
    STYPE = anyelement
);

-- Функция для вставки null-записей за день
CREATE OR REPLACE FUNCTION insert_null_data_for_date(selected_date DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $BODY$
BEGIN
    INSERT INTO data (date, item_id, value)
    SELECT selected_date, id, NULL
    FROM items_base
    WHERE begin_date <= selected_date
      AND (
          (type_id = 1 AND end_date >= selected_date) OR
          (type_id = 2)
      )
    ON CONFLICT (date, item_id) DO NOTHING;
END;
$BODY$;

-- Функция для подсчета суммы за последние n дней
CREATE OR REPLACE FUNCTION get_sum_last_n_days(
    p_item_id INT,
    p_date DATE,
    p_days INT DEFAULT 7
)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE
AS $BODY$
DECLARE
    v_result NUMERIC;
BEGIN
    SELECT SUM(value)
    INTO v_result
    FROM data t
    WHERE t.item_id = p_item_id
        AND t.date BETWEEN p_date - (p_days - 1) * INTERVAL '1 day'
        AND p_date;

    RETURN v_result;
END;
$BODY$;

-- Функция для расчета коэффициента в completion/pace
CREATE OR REPLACE FUNCTION calculate_multiplier(
    allow_overcompletion BOOLEAN,
    negative BOOLEAN,
    actual NUMERIC,
    target NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql IMMUTABLE
AS $BODY$
DECLARE
    multiplier NUMERIC;
BEGIN
    IF NOT allow_overcompletion THEN
        IF negative THEN
            IF actual < target OR actual > 2 * target THEN
                multiplier := 0;
            ELSE
                multiplier := -1;
            END IF;
        ELSE
            IF actual > target THEN
                multiplier := 0;
            ELSE
                multiplier := 1;
            END IF;
        END IF;
    ELSE
        IF negative THEN
            multiplier := -1;
        ELSE
            multiplier := 1;
        END IF;
    END IF;

    -- Additional adjustment
    IF NOT allow_overcompletion AND negative AND actual > 2 * target THEN
        multiplier := multiplier - 1;
    END IF;

    RETURN multiplier;
END;
$BODY$;

-- View для расчетов целей
DROP VIEW IF EXISTS goals_calc CASCADE;
CREATE VIEW goals_calc with (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            data.id,
            data.date,
            data.item_id,
            data.value,
            items_base.name,
            1 AS type_id,
            items_base.weight,
            items_base.begin_date,
            items_base.end_date,
            items_base.duration,
            (items_base.end_date - data.date + 1) AS remaining_duration,
            goals.add_to_sum,
            items_base.allow_overcompletion,
            COALESCE(goals.start_value, 0) AS start_value,
            items_base.target_value,
            goals.target_change,
            -- Плановое изменение на дату с начала учета
            (goals.target_change / goals.duration) * ((data.date - items_base.begin_date + 1)::DECIMAL) AS plan_change,
            -- Фактическое изменение на дату с начала учета
            CASE
                WHEN goals.add_to_sum THEN
                    COALESCE(SUM(data.value) OVER w_items, 0)
                ELSE
                    COALESCE(last_non_null_value(data.value) OVER w_items - goals.start_value, 0)
            END AS fact_change
        FROM
            data JOIN
            items_base ON data.item_id = items_base.id
            JOIN goals ON items_base.id = goals.id
        WINDOW w_items AS (PARTITION BY item_id ORDER BY date)
    )
    SELECT *,
        -- Плановое значение на дату с начала учета
        start_value + plan_change AS plan_value,
        -- Фактическое значение на дату с начала учета
        start_value + fact_change AS fact_value,
        -- Среднее изменение в день с начала учета
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        -- Оставшееся изменение до выполнения цели
        target_change - fact_change AS remaining_change,
        -- Ожидаемое значение на дату дедлайна
        (fact_change / NULLIF(date - begin_date + 1, 0)) * (remaining_duration - (value IS NOT NULL)::INTEGER) + fact_change AS expected_value,
        -- Необходимое изменение в день для достижения цели
        (target_change - fact_change) / NULLIF(remaining_duration - (value IS NOT NULL)::INTEGER, 0) AS daily_target_change,
        -- Процент выполнения цели
        fact_change / NULLIF(target_change, 0) * 100 AS completion,
        -- Текущий темп выполнения в процентах
        CASE
            WHEN plan_change = 0 THEN 0
            ELSE
                ((fact_change - plan_change) / NULLIF(plan_change, 0)) *
                calculate_multiplier(allow_overcompletion, false, fact_change, plan_change) + 1
        END * 100 AS pace
    FROM q1
);

-- View для расчетов привычек
DROP VIEW IF EXISTS habits_calc CASCADE;
CREATE VIEW habits_calc with (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            data.id,
            data.date,
            data.item_id,
            data.value,
            items_base.name,
            2 AS type_id,
            items_base.weight,
            items_base.begin_date,
            items_base.end_date,
            items_base.duration,
            (items_base.end_date - data.date + 1) AS remaining_duration,
            items_base.allow_overcompletion,
            habits.negative,
            -- Целевое значение за период
            items_base.target_value,
            --NULL::DECIMAL AS target_change,
            habits.interval_type,
            habits.interval_length,
            -- Фактическое значение на дату с начала интервала, скорректированое на дробную часть
            get_sum_last_n_days(item_id, date, CEIL(habits.interval_length)::INTEGER) / CEIL(habits.interval_length) * habits.interval_length AS fact_value,
            -- Плановое изменение на дату с начала учета
            SUM(items_base.target_value / habits.interval_length) OVER w_items AS plan_change,
            -- Фактическое изменение на дату с начала учета
            COALESCE(SUM(data.value) OVER w_items, 0) AS fact_change
        FROM
            data JOIN
            items_base ON data.item_id = items_base.id
            JOIN habits ON items_base.id = habits.id
        WINDOW w_items AS (PARTITION BY item_id ORDER BY date)
    )
    SELECT *,
        -- Среднее изменение в день с начала учета
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        -- Оставшееся изменение до выполнения цели
        target_value - fact_value AS remaining_value,
        -- Ожидаемое значение на дату дедлайна (если он установлен)
        -- CASE
        --     WHEN end_date IS NOT NULL THEN
        --         (fact_change / NULLIF(date - begin_date + 1, 0)) * (remaining_duration - (value IS NOT NULL)::INTEGER) + fact_change
        --     ELSE NULL
        -- END AS expected_value,
        -- Необходимое изменение в день для достижения цели
        (target_value - fact_value) / (GREATEST(interval_length - (date - begin_date) - 1, 1)) AS daily_target_change,
        -- Процент выполнения цели
        ((fact_value - target_value) / NULLIF(target_value, 0)) *
        calculate_multiplier(allow_overcompletion, negative, fact_value, target_value) + 1 * 100 AS completion,
        -- Текущий темп выполнения в процентах
        CASE
            WHEN plan_change = 0 THEN 0
            ELSE
                ((fact_change - plan_change) / NULLIF(plan_change, 0)) *
                calculate_multiplier(allow_overcompletion, negative, fact_change, plan_change) + 1
        END * 100 AS pace
    FROM q1
);

-- View для отображения данных с расчетами
DROP VIEW IF EXISTS items_calc CASCADE;
CREATE VIEW items_calc with (security_invoker = on) AS (
    SELECT * FROM goals_calc
    UNION ALL
    SELECT * FROM habits_calc
);

-- View для статистики дня
DROP VIEW IF EXISTS day_stats CASCADE;
CREATE VIEW day_stats with (security_invoker = on) AS (
    SELECT
    date,
    SUM(weight * pace) / SUM(weight) AS weighted_pace,
    SUM(weight * pace) / SUM(weight) - LAG(SUM(weight * pace) / SUM(weight))  OVER (ORDER BY date) AS day_result
    FROM items_calc
    GROUP BY date
);

-- Включаем RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE _dict_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE items_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE data ENABLE ROW LEVEL SECURITY;

-- Политики для _dict_types (добавлены)
DROP POLICY IF EXISTS "Users can view _dict_types" ON _dict_types;
CREATE POLICY "Users can view _dict_types" ON _dict_types FOR SELECT USING (true);

-- Политики для items_base
DROP POLICY IF EXISTS "Users can view own items_base" ON items_base;
CREATE POLICY "Users can view own items_base" ON items_base
    FOR SELECT USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can insert own items_base" ON items_base;
CREATE POLICY "Users can insert own items_base" ON items_base
    FOR INSERT WITH CHECK (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can update own items_base" ON items_base;
CREATE POLICY "Users can update own items_base" ON items_base
    FOR UPDATE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can delete own items_base" ON items_base;
CREATE POLICY "Users can delete own items_base" ON items_base
    FOR DELETE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

-- Политики для goals
DROP POLICY IF EXISTS "Users can view own goals" ON goals;
CREATE POLICY "Users can view own goals" ON goals
    FOR SELECT USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can insert own goals" ON goals;
CREATE POLICY "Users can insert own goals" ON goals
    FOR INSERT WITH CHECK (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can update own goals" ON goals;
CREATE POLICY "Users can update own goals" ON goals
    FOR UPDATE USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can delete own goals" ON goals;
CREATE POLICY "Users can delete own goals" ON goals
    FOR DELETE USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

-- Политики для habits
DROP POLICY IF EXISTS "Users can view own habits" ON habits;
CREATE POLICY "Users can view own habits" ON habits
    FOR SELECT USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can insert own habits" ON habits;
CREATE POLICY "Users can insert own habits" ON habits
    FOR INSERT WITH CHECK (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can update own habits" ON habits;
CREATE POLICY "Users can update own habits" ON habits
    FOR UPDATE USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can delete own habits" ON habits;
CREATE POLICY "Users can delete own habits" ON habits
    FOR DELETE USING (
        id IN (SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

-- Политики для data
DROP POLICY IF EXISTS "Users can view own data" ON data;
CREATE POLICY "Users can view own data" ON data
    FOR SELECT USING (
        item_id IN (
            SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can insert own data" ON data;
CREATE POLICY "Users can insert own data" ON data
    FOR INSERT WITH CHECK (
        item_id IN (
            SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can update own data" ON data;
CREATE POLICY "Users can update own data" ON data
    FOR UPDATE USING (
        item_id IN (
            SELECT id FROM items_base WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );
