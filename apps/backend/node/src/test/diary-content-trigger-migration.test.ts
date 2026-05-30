import fs from 'fs';
import path from 'path';

const migrationsDir = path.join(__dirname, '../../migrations');

function migrationFiles() {
  return fs
    .readdirSync(migrationsDir)
    .filter((file) => file.endsWith('.sql'))
    .sort();
}

describe('diary content trigger migrations', () => {
  it('guards the content-derived UPDATE trigger so explicit block writes are preserved', () => {
    const files = migrationFiles();
    const initialSchemaIndex = files.indexOf('001_init.sql');
    expect(initialSchemaIndex).toBeGreaterThanOrEqual(0);

    const migrationsAfterInitialSchema = files
      .slice(initialSchemaIndex + 1)
      .map((file) => fs.readFileSync(path.join(migrationsDir, file), 'utf8'))
      .join('\n');

    // The app supplies canonical blocks in PATCH /api/diary/entries/:id.
    // If the old BEFORE UPDATE trigger runs when NEW.blocks is explicitly changed,
    // any content edit reparses text into generated block IDs and wipes
    // userModified/nutrition/image metadata. The replacement trigger function must
    // only derive blocks for legacy content-only updates where blocks were not supplied.
    expect(migrationsAfterInitialSchema).toMatch(
      /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+"?public"?\."?set_diary_entry_content_derived"?/i,
    );
    expect(migrationsAfterInitialSchema).toMatch(
      /OLD\."?blocks"?\s+IS\s+NOT\s+DISTINCT\s+FROM\s+NEW\."?blocks"?/i,
    );
  });
});
