create or replace function assert.Exception(_sql text, _exception_message text default '', _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        BEGIN
            EXECUTE _sql;
        EXCEPTION WHEN OTHERS THEN
            IF _exception_message != '' AND _exception_message != SQLERRM THEN
                return assert.Fail(format('Exception not equal: %s (expected) != %s (actual)', _exception_message, SQLERRM), _description, _context);
            END IF;
            return true;
        END;

        return assert.Fail('No exception thrown', _description, _context);
    end;
$$ language plpgsql;
