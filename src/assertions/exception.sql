create or replace function assert.Exception(_sql text, _exception_message text default '', _exception_code text default '', _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        BEGIN
            EXECUTE _sql;
        EXCEPTION WHEN OTHERS THEN

            IF _exception_message != '' AND SQLERRM NOT LIKE _exception_message THEN
                return assert.Fail(format('Exception message not equal: %s (expected) != %s (actual)', _exception_message, SQLERRM), _description, _context);
            END IF;

            IF _exception_code != '' AND _exception_code != SQLSTATE THEN
                return assert.Fail(format('Exception code not equal: %s (expected) != %s (actual)', _exception_code, SQLSTATE), _description, _context);
            END IF;

            return true;
        END;

        return assert.Fail('No exception thrown', _description, _context);
    end;
$$ language plpgsql;
