-- Таблица пользователей
-- DROP TABLE IF EXISTS users CASCADE;
-- CREATE TABLE users (
--     id UUID PRIMARY KEY DEFAULT auth.uid(),  -- Supabase user ID
--     email VARCHAR(255) UNIQUE,
--     username VARCHAR(255),
--     first_name VARCHAR(255),
--     last_name VARCHAR(255),
--     created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
--     updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
-- );

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

-- Таблица задач/привычек
DROP TABLE IF EXISTS items CASCADE;
CREATE TABLE items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(64) NOT NULL,
    weight DECIMAL(5, 2),
    type_id INTEGER NOT NULL,
    begin_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    duration INTEGER GENERATED ALWAYS AS 
        (CASE WHEN end_date IS NULL THEN NULL ELSE ((end_date - begin_date) + 1) END) STORED,

    allow_overcompletion BOOLEAN NOT NULL DEFAULT TRUE,
    negative BOOLEAN,
    add_to_sum BOOLEAN,
    start_value DECIMAL(10, 2),
    target_value DECIMAL(10, 2) NOT NULL,
    target_change DECIMAL(10, 2) GENERATED ALWAYS AS
        (CASE WHEN type_id = 1 THEN (target_value - COALESCE(start_value, 0)) ELSE NULL END) STORED,

    interval_type interval_type,
    interval_value DECIMAL(10, 6) GENERATED ALWAYS AS (
        CASE WHEN type_id = 1 THEN NULL ELSE
            CASE interval_type
                WHEN 'day' THEN 1
                WHEN 'week' THEN 7
                WHEN 'month' THEN 30.436875
                WHEN 'quarter' THEN 91.310625
                WHEN 'year' THEN 365.2425
            END
        END
    ) STORED,

    -- Проверки
    CONSTRAINT correct_date_check
        CHECK (end_date IS NULL OR end_date >= begin_date),
    CONSTRAINT valid_weight_check
        CHECK (weight IS NULL OR (weight >= 0 AND weight <= 100)),
    CONSTRAINT end_date_required_for_goals
        CHECK (type_id != 1 OR end_date IS NOT NULL),
    CONSTRAINT add_to_sum_required_for_goals
        CHECK (type_id != 1 OR add_to_sum IS NOT NULL),
    CONSTRAINT negative_required_for_habits
        CHECK (type_id != 2 OR negative IS NOT NULL),
    CONSTRAINT interval_type_required_for_habits
        CHECK (type_id != 2 OR interval_type IS NOT NULL),

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

-- Таблица данных по дням
DROP TABLE IF EXISTS data CASCADE;
CREATE TABLE data (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date DATE NOT NULL,
    item_id INTEGER NOT NULL,
    value DECIMAL(10, 2),

    CONSTRAINT unique_date_item_id UNIQUE(date, item_id),
    CONSTRAINT fk_item
        FOREIGN KEY(item_id)
        REFERENCES items(id)
        ON DELETE CASCADE
);

-- Функции для расчета последнего не null значения в days
CREATE OR REPLACE FUNCTION last_non_null_state(
	state anyelement,
	value anyelement)
    RETURNS anyelement
    LANGUAGE 'plpgsql'
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
    FROM items
    WHERE begin_date <= selected_date
      AND (end_date IS NULL OR end_date >= selected_date)
    ON CONFLICT (date, item_id) DO NOTHING;
END;
$BODY$;

-- View для отображения данных с расчетами
DROP VIEW IF EXISTS days CASCADE;
CREATE VIEW days with (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            --Переменные для расчетов с привычками
            1000 AS max_percent_over,
            100 AS max_percent_no_over,
            data.id,
            data.date,
            data.item_id,
            data.value,
            items.name,
            items.type_id,
            items.weight,
            items.begin_date,
            items.end_date,
            CASE WHEN end_date IS NULL THEN NULL ELSE (items.end_date - data.date + 1) END AS remaining_duration,
            items.add_to_sum,
            items.allow_overcompletion,
            items.negative,
            CASE WHEN type_id = 1 THEN COALESCE(items.start_value, 0) ELSE NULL END AS start_value,
            items.target_value,
            items.target_change,
            items.interval_type,
            -- SUM(COALESCE(data.value, 0)) OVER w_items AS acc_value,
            -- SUM(items.target_value / items.interval_value) OVER w_items AS acc_plan_value,
            CASE 
                WHEN items.type_id = 1 THEN (items.target_change / items.duration) * ((data.date - items.begin_date + 1)::DECIMAL)
                ELSE SUM(items.target_value / items.interval_value) OVER w_items
            END AS plan_change,
            CASE WHEN items.type_id = 1 THEN COALESCE(items.start_value, 0) + (items.target_change / items.duration) * ((data.date - items.begin_date + 1)::DECIMAL) ELSE NULL END AS plan_value,
            CASE
                WHEN type_id = 2 THEN SUM(COALESCE(data.value, 0)) OVER w_items
                WHEN add_to_sum THEN
                    COALESCE(SUM(data.value) OVER w_items, 0)
                ELSE
                    last_non_null_value(data.value) OVER w_items - COALESCE(start_value, 0)
            END AS fact_change
        FROM
            data JOIN
            items ON data.item_id = items.id
        WINDOW w_items AS (PARTITION BY item_id ORDER BY date)
        )
    SELECT *,
        fact_change + start_value AS fact_value,
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        target_change - fact_change AS remaining_change,
        --Ожидаемое значение на дату дедлайна
        (fact_change / NULLIF(date - begin_date + 1, 0)) * (remaining_duration - (value IS NOT NULL)::INTEGER) + fact_change + start_value AS expected_value,
        --Изменение в день для достижения цели (если сегодня данные уже внесены, то делим на остаток с завтрашнего дня)
        (target_change - fact_change) / NULLIF(remaining_duration - (value IS NOT NULL)::INTEGER, 0) AS daily_target_change,
        CASE
            WHEN type_id = 1 THEN fact_change / NULLIF(target_change, 0) * 100
            WHEN type_id = 2 THEN value / target_value * 100
        END AS completion,
        CASE 
            WHEN plan_change = 0 THEN 0
            ELSE 
                ((fact_change - plan_change)::DECIMAL / plan_change) 
                * 
                CASE 
                    WHEN negative THEN
                        CASE 
                            WHEN NOT allow_overcompletion AND (fact_change < plan_change OR fact_change > 2*plan_change) THEN 0
                            ELSE -1
                        END
                    ELSE
                        CASE 
                            WHEN NOT allow_overcompletion AND fact_change > plan_change THEN 0
                            ELSE 1
                        END
                END
                +
                CASE 
                    WHEN NOT allow_overcompletion AND negative AND fact_change > 2*plan_change THEN -1
                    ELSE 0
                END
                + 1
        END * 100 AS pace
        -- CASE
        --     WHEN type_id = 1 THEN fact_change / plan_change * 100
        --     WHEN type_id = 2 THEN CASE
        --         WHEN negative AND target_value = 0 THEN CASE WHEN fact_change = 0 THEN 100 ELSE 0 END
        --         WHEN plan_change = 0 THEN 0
        --         WHEN negative THEN
        --             CASE
        --                 WHEN allow_overcompletion THEN CASE WHEN fact_change < 0 THEN max_percent_over ELSE LEAST( COALESCE( (plan_change / NULLIF(fact_change, 0)) * 100 , max_percent_over ) , max_percent_over ) END
        --                 ELSE CASE WHEN fact_change < 0 THEN max_percent_no_over ELSE LEAST( COALESCE( (plan_change / NULLIF(fact_change, 0)) * 100 , max_percent_no_over ) , max_percent_no_over ) END
        --             END
        --         ELSE
        --             CASE
        --                 WHEN allow_overcompletion THEN (fact_change / plan_change) * 100
        --                 ELSE GREATEST(LEAST((fact_change / plan_change) * 100, max_percent_no_over), 0)
        --             END
        --     END
        -- END AS pace
    FROM q1
);

-- Включаем RLS для таблиц
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE _dict_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE data ENABLE ROW LEVEL SECURITY;

-- Политики для таблицы users
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (id = (auth.jwt() ->> 'sub')::uuid);

-- Политики для таблицы items
DROP POLICY IF EXISTS "Users can view own items" ON items;
CREATE POLICY "Users can view own items" ON items
    FOR SELECT USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can insert own items" ON items;
CREATE POLICY "Users can insert own items" ON items
    FOR INSERT WITH CHECK (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can update own items" ON items;
CREATE POLICY "Users can update own items" ON items
    FOR UPDATE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can delete own items" ON items;
CREATE POLICY "Users can delete own items" ON items
    FOR DELETE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

-- Политики для таблицы data
DROP POLICY IF EXISTS "Users can view own data" ON data;
CREATE POLICY "Users can view own data" ON data
    FOR SELECT USING (
        item_id IN (
            SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can insert own data" ON data;
CREATE POLICY "Users can insert own data" ON data
    FOR INSERT WITH CHECK (
        item_id IN (
            SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can update own data" ON data;
CREATE POLICY "Users can update own data" ON data
    FOR UPDATE USING (
        item_id IN (
            SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );
