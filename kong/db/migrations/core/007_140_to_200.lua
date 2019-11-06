return {
  postgres = {
    up = [[
      DO $$
      BEGIN
        ALTER TABLE IF EXISTS ONLY "plugins" DROP COLUMN "run_on";
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END;
      $$;


      DO $$
      BEGIN
        DROP TABLE IF EXISTS "cluster_ca";
      END;
      $$;
    ]],
  },

  cassandra = {
    up = [[
      DROP INDEX IF EXISTS plugins_run_on_idx;
      ALTER TABLE plugins DROP run_on;


      DROP TABLE IF EXISTS cluster_ca;
    ]],
  },
}
