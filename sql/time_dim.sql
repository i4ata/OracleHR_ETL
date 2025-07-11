DELIMITER $$

CREATE PROCEDURE populate_time_dim(start_date DATE, end_date DATE)
BEGIN
    SET @current_date = start_date;

    WHILE @current_date <= end_date DO
        INSERT INTO time_dim (
            surrogate_time_id,
            time_id,
            dates,
            year,
            quarter,
            month,
            week,
            day,
            day_of_week,
            fiscal_year,
            fiscal_quarter
        )
        VALUES (
            CRC32(DATE_FORMAT(@current_date, '%Y%m%d')),  -- surrogate_time_id
            DATE_FORMAT(@current_date, '%Y%m%d'),         -- time_id
            @current_date,                                -- dates
            YEAR(@current_date),                          -- year
            QUARTER(@current_date),                       -- quarter
            MONTH(@current_date),                         -- month
            WEEK(@current_date, 3),                       -- ISO week
            DAY(@current_date),                           -- day
            DAYNAME(@current_date),                       -- day_of_week
            YEAR(@current_date),                          -- fiscal_year (same as year)
            QUARTER(@current_date)                        -- fiscal_quarter (same as quarter)
        );
        SET @current_date = DATE_ADD(@current_date, INTERVAL 1 DAY);
    END WHILE;
END$$

DELIMITER ;

-- Execute to populate:
CALL populate_time_dim('1995-01-01', '2024-12-31');
