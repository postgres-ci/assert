create or replace function assert.False(_value boolean, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _value IS NOT FALSE THEN
            return assert.Fail('Should be false', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;
