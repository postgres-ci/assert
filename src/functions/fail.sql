create or replace function assert.fail(
    _message text, 
    _comment text
) returns boolean as $$
    declare 
        _current_test_id int;
    begin 

        _current_test_id = assert.get_current_test_id();

        IF _current_test_id IS NULL THEN 

            RAISE EXCEPTION '%', (
                SELECT
                    CASE WHEN _comment != '' THEN
                        _message || '. ' || _comment
                    ELSE _message END
            );

        END IF;

        INSERT INTO assert.errors (
            test_id,
            error 
        ) VALUES (
            _current_test_id,
            (_message, _comment)::assert.error
        );

        return false;
    end;
$$ language plpgsql security definer;