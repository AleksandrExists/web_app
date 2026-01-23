-- Insert test goal item
INSERT INTO items (user_id, name, type_id, begin_date, end_date, target_value, allow_overcompletion, weight)
VALUES
    ('232cff07-fe46-4fbe-a1fe-f91e39146622', 'Positive_g_null_start', 1, '2025-12-01', '2026-01-19', 400, TRUE, 100.0);

INSERT INTO goals (id, add_to_sum, start_value)
VALUES
    (1, TRUE, NULL);

-- Insert daily weight data (decreasing from 80 to 75 kg)
INSERT INTO data (date, item_id, value) VALUES
('2025-12-01', 1, 80.0),

-- Insert test monthly habits
INSERT INTO items (user_id, name, type_id, begin_date, end_date, target_value, allow_overcompletion, weight)
VALUES
    ('232cff07-fe46-4fbe-a1fe-f91e39146622', 'Positive_monthly_no_over', 2, '2025-12-01', NULL, 10, FALSE, 100.0),
    ('232cff07-fe46-4fbe-a1fe-f91e39146622', 'Positive_monthly_allow_over', 2, '2025-12-01', NULL, 10, TRUE, 100.0),
    ('232cff07-fe46-4fbe-a1fe-f91e39146622', 'Negative_monthly_no_over', 2, '2025-12-01', NULL, 5, FALSE, 100.0),
    ('232cff07-fe46-4fbe-a1fe-f91e39146622', 'Negative_monthly_allow_over', 2, '2025-12-01', NULL, 5, TRUE, 100.0);

INSERT INTO habits (id, negative, interval_type)
VALUES
    (2, FALSE, 'month'),
    (3, FALSE, 'month'),
    (4, TRUE, 'month'),
    (5, TRUE, 'month');
