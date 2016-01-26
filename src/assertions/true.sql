create or replace function assert.True(_value boolean, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _value IS NOT TRUE THEN
            return assert.Fail('Should be true', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;
