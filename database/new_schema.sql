-- Functions for calculating the last non-null value in days
CREATE OR REPLACE FUNCTION last_non_null_state(
    state anyelement,
    value anyelement
)
RETURNS anyelement
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN COALESCE(value, state);
END;
$$;

CREATE OR REPLACE AGGREGATE last_non_null_value(anyelement) (
    SFUNC = last_non_null_state,
    STYPE = anyelement
);

-- Function to insert null records for a date
CREATE OR REPLACE FUNCTION insert_null_data_for_date(selected_date DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO data (date, item_id, value)
    SELECT selected_date, id, NULL
    FROM items
    WHERE begin_date <= selected_date
        AND (
            (type_id = 1 AND end_date >= selected_date) OR
            (type_id = 2 AND (end_date IS NULL OR end_date >= selected_date))
      )
    ON CONFLICT (date, item_id) DO NOTHING;
END;
$$;

-- Function to calculate sum for last n days
CREATE OR REPLACE FUNCTION get_sum_last_n_days(
    p_item_id INT,
    p_date DATE,
    p_days INT DEFAULT 7
)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE
AS $$
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
$$;

-- Function to calculate completion for goals/habits
CREATE OR REPLACE FUNCTION calculate_completion(
    fact NUMERIC,
    plan NUMERIC,
    allow_overcompletion BOOLEAN,
    negative BOOLEAN
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    result NUMERIC;
BEGIN
    result := COALESCE((fact - plan) / NULLIF(plan, 0), 0) *
        CASE
            WHEN NOT allow_overcompletion THEN
                CASE
                    WHEN negative THEN
                        CASE
                            WHEN fact < plan OR fact > 2 * plan THEN 0
                            ELSE -1
                        END
                    ELSE
                        CASE
                            WHEN fact > plan THEN 0
                            ELSE 1
                        END
                END
            ELSE
                CASE
                    WHEN negative THEN -1
                    ELSE 1
                END
        END
        +
        CASE
            WHEN NOT allow_overcompletion AND negative AND fact > 2 * plan THEN -1
            ELSE 0
        END
        + 1;
    RETURN result * 100;
END;
$$;

-- Users table
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

-- Dictionary for item types
DROP TABLE IF EXISTS _dict_types CASCADE;
CREATE TABLE _dict_types (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(32) NOT NULL UNIQUE
);

-- Insert item types
INSERT INTO _dict_types
(name)
VALUES
    ('Goal'),
    ('Habit');

-- Habit interval type
DROP TYPE IF EXISTS interval_type CASCADE;
CREATE TYPE interval_type AS ENUM ('day', 'week', 'month', 'quarter', 'year');

-- Common table for items
DROP TABLE IF EXISTS items CASCADE;
CREATE TABLE items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(64) NOT NULL,
    weight NUMERIC(5, 2),
    type_id INTEGER NOT NULL,
    begin_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,  -- Required for goals, optional for habits
    duration INTEGER GENERATED ALWAYS AS
        ((end_date - begin_date) + 1) STORED,
    allow_overcompletion BOOLEAN NOT NULL DEFAULT TRUE,
    target_value NUMERIC NOT NULL,

    -- Checks
    CONSTRAINT valid_weight_check
        CHECK (weight IS NULL OR (weight >= 0 AND weight <= 100)),
    CONSTRAINT correct_date_check
        CHECK (end_date IS NULL OR end_date >= begin_date),
    CONSTRAINT goal_end_date_check
        CHECK (type_id <> 1 OR end_date IS NOT NULL),

    -- Foreign keys
    CONSTRAINT fk_item_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_item_type
        FOREIGN KEY (type_id)
        REFERENCES _dict_types(id)
        ON DELETE RESTRICT
);

-- Goals table
DROP TABLE IF EXISTS goals CASCADE;
CREATE TABLE goals (
    id INTEGER PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
    add_to_sum BOOLEAN NOT NULL,
    start_value NUMERIC
);

-- Habits table
DROP TABLE IF EXISTS habits CASCADE;
CREATE TABLE habits (
    id INTEGER PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
    negative BOOLEAN NOT NULL DEFAULT FALSE,
    interval_type interval_type NOT NULL,
    interval_length NUMERIC GENERATED ALWAYS AS (
        CASE interval_type
            WHEN 'day' THEN 1
            WHEN 'week' THEN 7
            WHEN 'month' THEN 30.436875
            WHEN 'quarter' THEN 91.310625
            WHEN 'year' THEN 365.2425
        END
    ) STORED
);

-- Daily data table
DROP TABLE IF EXISTS data CASCADE;
CREATE TABLE data (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date DATE NOT NULL,
    item_id INTEGER NOT NULL,
    value NUMERIC,

    CONSTRAINT unique_date_item_id UNIQUE(date, item_id),
    CONSTRAINT fk_item
        FOREIGN KEY(item_id)
        REFERENCES items(id)
        ON DELETE CASCADE
);


-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE _dict_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE data ENABLE ROW LEVEL SECURITY;

-- Policies for _dict_types
DROP POLICY IF EXISTS "Users can view _dict_types" ON _dict_types;
CREATE POLICY "Users can view _dict_types" ON _dict_types FOR SELECT USING (true);

-- Policies for items
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

-- Policies for goals
DROP POLICY IF EXISTS "Users can view own goals" ON goals;
CREATE POLICY "Users can view own goals" ON goals
    FOR SELECT USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can insert own goals" ON goals;
CREATE POLICY "Users can insert own goals" ON goals
    FOR INSERT WITH CHECK (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can update own goals" ON goals;
CREATE POLICY "Users can update own goals" ON goals
    FOR UPDATE USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can delete own goals" ON goals;
CREATE POLICY "Users can delete own goals" ON goals
    FOR DELETE USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

-- Policies for habits
DROP POLICY IF EXISTS "Users can view own habits" ON habits;
CREATE POLICY "Users can view own habits" ON habits
    FOR SELECT USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can insert own habits" ON habits;
CREATE POLICY "Users can insert own habits" ON habits
    FOR INSERT WITH CHECK (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can update own habits" ON habits;
CREATE POLICY "Users can update own habits" ON habits
    FOR UPDATE USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

DROP POLICY IF EXISTS "Users can delete own habits" ON habits;
CREATE POLICY "Users can delete own habits" ON habits
    FOR DELETE USING (
        id IN (SELECT id FROM items WHERE user_id = (auth.jwt() ->> 'sub')::uuid)
    );

-- Policies for data
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





-- Calculated constants for goals
DROP VIEW IF EXISTS goals_calc CASCADE;
CREATE VIEW goals_calc WITH (security_invoker = on) AS
    SELECT
        items.*,
        goals.add_to_sum,
        -- Target change in value
        (items.target_value - COALESCE(goals.start_value, 0)) AS target_change,
        -- Initial value
        COALESCE(goals.start_value, 0) AS start_value,
        -- Planned daily change to achieve goal
        (items.target_value - COALESCE(goals.start_value, 0)) / items.duration AS plan_daily_change
    FROM
        items JOIN
        goals ON items.id = goals.id;

-- Calculated constants for habits
DROP VIEW IF EXISTS habits_calc CASCADE;
CREATE VIEW habits_calc WITH (security_invoker = on) AS
    SELECT
        items.*,
        habits.negative,
        habits.interval_type,
        habits.interval_length,
        -- Planned daily change to achieve goal
        items.target_value / habits.interval_length AS plan_daily_change
    FROM
        items JOIN
        habits ON items.id = habits.id;

-- View for goal calculations
DROP VIEW IF EXISTS goals_days_calc CASCADE;
CREATE VIEW goals_days_calc WITH (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            data.id,
            data.date,
            data.item_id,
            data.value,
            goals_calc.name,
            1 AS type_id,
            goals_calc.weight,
            goals_calc.begin_date,
            goals_calc.end_date,
            goals_calc.duration,
            (goals_calc.end_date - data.date + 1) AS remaining_duration,
            goals_calc.add_to_sum,
            goals_calc.allow_overcompletion,
            goals_calc.start_value,
            goals_calc.target_value,
            goals_calc.target_change,
            -- Planned change from begin_date
            goals_calc.plan_daily_change * ((data.date - goals_calc.begin_date + 1)::NUMERIC) AS plan_change,
            -- Actual change from begin_date
            CASE
                WHEN goals_calc.add_to_sum THEN
                    COALESCE(SUM(data.value) OVER w_items, 0)
                ELSE
                    COALESCE(last_non_null_value(data.value) OVER w_items - goals_calc.start_value, 0)
            END AS fact_change
        FROM
            data JOIN
            goals_calc ON data.item_id = goals_calc.id
        WINDOW w_items AS (PARTITION BY item_id ORDER BY date)
    )
    SELECT *,
        -- Planned value from begin_date
        start_value + plan_change AS plan_value,
        -- Actual value from begin_date
        start_value + fact_change AS fact_value,
        -- Average change per day from begin_date
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        -- Remaining change to achieve goal
        target_change - fact_change AS remaining_change,
        -- Expected value at deadline
        (fact_change / NULLIF(date - begin_date + 1, 0)) * (remaining_duration - (value IS NOT NULL)::INTEGER) + fact_change AS expected_value,
        -- Required daily change to achieve goal
        (target_change - fact_change) / NULLIF(remaining_duration - (value IS NOT NULL)::INTEGER, 0) AS daily_target_change,
        -- Goal completion percentage
        calculate_completion(fact_change, target_change, allow_overcompletion, FALSE) AS completion,
        -- Current pace percentage
        CASE
            WHEN plan_change = 0 THEN 0
            ELSE calculate_completion(fact_change, plan_change, allow_overcompletion, FALSE)
        END AS pace
    FROM q1
);

-- View for habit calculations
DROP VIEW IF EXISTS habits_days_calc CASCADE;
CREATE VIEW habits_days_calc WITH (security_invoker = on) AS (
    WITH q1 AS(
        SELECT
            data.id,
            data.date,
            data.item_id,
            data.value,
            habits_calc.name,
            2 AS type_id,
            habits_calc.weight,
            habits_calc.begin_date,
            habits_calc.end_date,
            habits_calc.duration,
            (habits_calc.end_date - data.date + 1) AS remaining_duration,
            habits_calc.allow_overcompletion,
            habits_calc.negative,
            -- Target value per period
            habits_calc.target_value,
            habits_calc.interval_type,
            habits_calc.interval_length,
            -- Actual value adjusted for fractional part
            COALESCE(get_sum_last_n_days(item_id, date, CEIL(habits_calc.interval_length)::INTEGER) /
                CEIL(habits_calc.interval_length) * habits_calc.interval_length, 0) AS fact_value,
            -- Planned change from begin_date
            --SUM(habits_calc.plan_daily_change) OVER w_items AS plan_change,
            habits_calc.plan_daily_change * ((data.date - habits_calc.begin_date + 1)::NUMERIC) AS plan_change,
            -- Actual change from begin_date
            COALESCE(SUM(data.value) OVER w_items, 0) AS fact_change
        FROM
            data JOIN
            habits_calc ON data.item_id = habits_calc.id
        WINDOW w_items AS (PARTITION BY item_id ORDER BY date)
    )
    SELECT *,
        -- Average change per day from begin_date
        fact_change / NULLIF(date - begin_date + 1, 0) AS avg_change,
        -- Remaining change to achieve goal
        target_value - fact_value AS remaining_value,
        -- Required daily change to achieve goal
        (target_value - fact_value) / (GREATEST(interval_length - (date - begin_date) - 1, 1)) AS daily_target_change,
        -- Goal completion percentage
        calculate_completion(fact_value, target_value, allow_overcompletion, negative) AS completion,
        -- Current pace percentage
        CASE
            WHEN plan_change = 0 THEN 0
            ELSE calculate_completion(fact_change, plan_change, allow_overcompletion, negative)
        END AS pace
    FROM q1
);

-- View for displaying data with calculations
DROP VIEW IF EXISTS items_days_calc CASCADE;
CREATE VIEW items_days_calc WITH (security_invoker = on) AS (
    -- Goals data
    SELECT
        date,
        item_id,
        value,
        name,
        type_id,
        weight,
        begin_date,
        end_date,
        duration,
        remaining_duration,
        add_to_sum,
        allow_overcompletion,
        NULL AS negative,          -- Habit-specific
        start_value,
        target_value,
        NULL AS interval_type,     -- Habit-specific
        NULL AS interval_length,   -- Habit-specific
        target_change,
        plan_change,
        fact_change,
        plan_value,
        fact_value,
        avg_change,
        remaining_change,
        expected_value,
        daily_target_change,
        completion,
        pace
    FROM goals_days_calc
    UNION ALL
    -- Habits data
    SELECT
        date,
        item_id,
        value,
        name,
        type_id,
        weight,
        begin_date,
        end_date,
        duration,
        remaining_duration,
        NULL AS add_to_sum,        -- Goal-specific
        allow_overcompletion,
        negative,
        NULL AS start_value,       -- Goal-specific
        target_value,
        interval_type,
        interval_length,
        NULL AS target_change,     -- Goal-specific
        plan_change,
        fact_change,
        NULL AS plan_value,        -- Goal-specific
        fact_value,
        avg_change,
        remaining_value,
        NULL AS expected_value,    -- Goal-specific
        daily_target_change,
        completion,
        pace
    FROM habits_days_calc
);

-- View for day statistics
DROP VIEW IF EXISTS day_stats CASCADE;
CREATE VIEW day_stats WITH (security_invoker = on) AS (
    SELECT
    date,
    SUM(weight * pace) / SUM(weight) AS weighted_pace,
    SUM(weight * pace) / SUM(weight) - LAG(SUM(weight * pace) / SUM(weight))  OVER (ORDER BY date) AS day_result
    FROM items_days_calc
    GROUP BY date
);

DROP VIEW IF EXISTS __temp_view;
CREATE VIEW __temp_view WITH (security_invoker = on) AS (
    SELECT
        date, value, target_value, interval_length, plan_change, fact_change, fact_value, avg_change, remaining_change,
        daily_target_change, completion, pace
    FROM items_days_calc
);

