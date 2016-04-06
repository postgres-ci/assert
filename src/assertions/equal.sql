create or replace function assert.equal(_expected anyelement, _actual anyelement, _comment text default '') returns boolean as $$
    declare
        _context text;
    begin

        IF _expected != _actual THEN

            GET DIAGNOSTICS _context = PG_CONTEXT;

            return assert.fail(format('Not equal: %s (expected) != %s (actual)', _expected, _actual), _comment, _context);
        END IF;

        return true;
    end;
$$ language plpgsql security definer;