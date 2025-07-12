CREATE TABLE test (
    surrogate_employee_id CHAR(32) PRIMARY KEY,
    test_id DECIMAL(6,0) NOT NULL,
    f1 VARCHAR(41),
    f2 DECIMAL
);

DELIMITER $$

CREATE PROCEDURE insert_into_test(
    IN p_test_id DECIMAL(6,0),
    IN p_f1 VARCHAR(41),
    IN p_f2 DECIMAL
)
BEGIN
    UPDATE test 
    SET is_current = FALSE      
    WHERE test_id = p_test_id;

    INSERT INTO test (surrogate_employee_id, test_id, f1, f2)
    VALUES (MD5(CONCAT(p_test_id, p_f1, p_f2)), p_test_id, p_f1, p_f2);
END $$

DELIMITER ;

CREATE table staging_test (
    test_id DECIMAL,
    f1 VARCHAR(41),
    f2 DECIMAL
);

INSERT INTO staging_test
VALUES (123,'laino',3), (124,'govno',2);

call insert_into_test(SELECT * from staging);
