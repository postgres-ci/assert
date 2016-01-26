create or replace function assert.NotEqual(_expected anyelement, _actual anyelement, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _expected = _actual THEN
            return assert.Fail(format('Should not be: %s', _actual), _description, _context);
        END IF;

        return true;
    end;
$$ language plpgsql;
