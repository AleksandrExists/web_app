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
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- Таблица задач/привычек
DROP TABLE IF EXISTS tasks CASCADE;
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(64) NOT NULL,
    weight DECIMAL(5, 2),
    add_to_sum BOOLEAN NOT NULL DEFAULT TRUE,
    type_id INTEGER NOT NULL,
    start_value DECIMAL(10, 2) NOT NULL DEFAULT 0,
    target_value DECIMAL(10, 2) NOT NULL,
    target_change DECIMAL(10, 2) GENERATED ALWAYS AS (target_value - start_value) STORED,
    begin_date DATE NOT NULL DEFAULT(CURRENT_DATE - 2),
    end_date DATE NOT NULL DEFAULT(CURRENT_DATE + 2),
    duration INTEGER GENERATED ALWAYS AS ((end_date - begin_date) + 1) STORED

    -- Проверки
    CONSTRAINT correct_date_check
        CHECK (end_date >= begin_date),
    CONSTRAINT valid_weight_check
        CHECK (weight IS NULL OR (weight >= 0 AND weight <= 100)),

    -- Внешние ключи
    CONSTRAINT fk_task_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_task_type
        FOREIGN KEY (type_id)
        REFERENCES _dict_types(id)
        ON DELETE RESTRICT,

    -- Уникальность названия для пользователя
    CONSTRAINT unique_user_task_name UNIQUE(user_id, name)
);

-- Таблица данных по дням
DROP TABLE IF EXISTS data CASCADE;
CREATE TABLE data (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    task_id INTEGER NOT NULL,
    value DECIMAL(10, 2),

    CONSTRAINT unique_date_task_id UNIQUE(date, task_id),
    CONSTRAINT fk_task
        FOREIGN KEY(task_id)
        REFERENCES tasks(id)
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

-- View для отображения данных с расчетами
DROP VIEW IF EXISTS days CASCADE;
CREATE VIEW days with (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            data.id,
            data.date,
            data.task_id,
            tasks.name,
            tasks.begin_date,
            tasks.end_date,
            (tasks.end_date - data.date + 1) AS remaining_duration,
            tasks.weight,
            tasks.add_to_sum,
            tasks.type_id,
            tasks.start_value,
            tasks.target_value,
            tasks.target_change,
            (tasks.target_change / tasks.duration::DECIMAL) * ((data.date - tasks.begin_date + 1)::DECIMAL) AS plan_change,
            tasks.start_value + (tasks.target_change / tasks.duration::DECIMAL) * ((data.date - tasks.begin_date + 1)::DECIMAL) AS plan_value,
            data.value,
            CASE
                WHEN add_to_sum THEN
                    COALESCE(SUM(data.value) OVER w_tasks, 0)
                ELSE
                    COALESCE(last_non_null_value(data.value) OVER w_tasks - tasks.start_value, 0)
            END AS fact_change
        FROM
            data JOIN
            tasks ON data.task_id = tasks.id
        WINDOW w_tasks AS (PARTITION BY task_id ORDER BY date)
        )
    SELECT *,
        fact_change + start_value AS fact_value,
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        target_change - fact_change AS remaining_change,
        --Ожидаемое значение на дату дедлайна
        (fact_change / NULLIF(date - begin_date + 1, 0)) * (remaining_duration - (value IS NOT NULL)::INTEGER) + fact_change + start_value AS expected_value,
        --Изменение в день для достижения цели (если сегодня данные уже внесены, то делим на остаток с завтрашнего дня)
        (target_change - fact_change) / NULLIF(remaining_duration - (value IS NOT NULL)::INTEGER, 0) AS daily_target_change,
        ROUND(fact_change / NULLIF(target_change, 0) * 100, 2) AS completion,
        ROUND(fact_change / NULLIF(plan_change, 0) * 100, 2) AS pace
    FROM q1
);

-- Включаем RLS для таблиц
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE _dict_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
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

-- Политики для таблицы tasks
DROP POLICY IF EXISTS "Users can view own tasks" ON tasks;
CREATE POLICY "Users can view own tasks" ON tasks
    FOR SELECT USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can insert own tasks" ON tasks;
CREATE POLICY "Users can insert own tasks" ON tasks
    FOR INSERT WITH CHECK (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can update own tasks" ON tasks;
CREATE POLICY "Users can update own tasks" ON tasks
    FOR UPDATE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

DROP POLICY IF EXISTS "Users can delete own tasks" ON tasks;
CREATE POLICY "Users can delete own tasks" ON tasks
    FOR DELETE USING (user_id = (auth.jwt() ->> 'sub')::uuid);

-- Политики для таблицы data
DROP POLICY IF EXISTS "Users can view own data" ON data;
CREATE POLICY "Users can view own data" ON data
    FOR SELECT USING (
        task_id IN (
            SELECT id FROM tasks WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can insert own data" ON data;
CREATE POLICY "Users can insert own data" ON data
    FOR INSERT WITH CHECK (
        task_id IN (
            SELECT id FROM tasks WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

DROP POLICY IF EXISTS "Users can update own data" ON data;
CREATE POLICY "Users can update own data" ON data
    FOR UPDATE USING (
        task_id IN (
            SELECT id FROM tasks WHERE user_id = (auth.jwt() ->> 'sub')::uuid
        )
    );

-- Триггеры для автоматического создания записей в data при INSERT tasks
CREATE OR REPLACE FUNCTION tasks_insert_trigger_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    -- Вставляем записи для каждого дня используя generate_series
    INSERT INTO data (date, task_id)
    SELECT
        NEW.begin_date + ((n - 1) * INTERVAL '1 day'),
        NEW.id
    FROM generate_series(1, NEW.duration) AS n
    ON CONFLICT (date, task_id) DO NOTHING;

    RETURN NEW;
END;
$BODY$;

CREATE OR REPLACE TRIGGER insert_task
    AFTER INSERT ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION tasks_insert_trigger_func();

-- Триггеры для автоматического обновления записей в data при UPDATE tasks
CREATE OR REPLACE FUNCTION tasks_update_trigger_func()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    -- Удаляем дни вне нового диапазона
    DELETE FROM data WHERE task_id = OLD.id AND (date < NEW.begin_date OR date > NEW.end_date);

    -- Вставляем новые дни в диапазоне
    INSERT INTO data (date, task_id)
    SELECT
        NEW.begin_date + ((n - 1) * INTERVAL '1 day'),
        NEW.id
    FROM generate_series(1, NEW.duration) AS n
    WHERE NOT EXISTS (SELECT 1 FROM data WHERE date = NEW.begin_date + ((n - 1) * INTERVAL '1 day') AND task_id = NEW.id);

    RETURN NEW;
END;
$BODY$;

CREATE OR REPLACE TRIGGER update_tasks
    AFTER UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION tasks_update_trigger_func();

-- Добавление типов задач
INSERT INTO _dict_types
(name)
VALUES
    ('Цель'),
    ('Привычка'),
    ('Среднее'),
    ('Проект');
