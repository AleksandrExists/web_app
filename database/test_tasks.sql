-- INSERT INTO items (user_id, name, type_id, weight, begin_date, end_date, allow_overcompletion, add_to_sum, target_value) VALUES
--     ('4c988b55-7110-4ec6-976d-107501142f4b', 'task', 1, 30, CURRENT_DATE - 5, CURRENT_DATE - 1, TRUE, TRUE, 100);

INSERT INTO items (user_id, name, type_id, weight, begin_date, allow_overcompletion, negative, target_value, interval_type) VALUES
    ('4c988b55-7110-4ec6-976d-107501142f4b', 'Up', 2, 8, '2026-01-01', TRUE, FALSE, 1, 'day');
