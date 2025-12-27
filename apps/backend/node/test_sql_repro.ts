
import Database from './src/services/database';

async function testSqlFunction() {
    try {
        const validContent = "Had a healthy breakfast";
        // Explicitly cast BOTH arguments
        const result = await Database.query(
            `SELECT public.has_meaningful_content(CAST($1 AS text), CAST($2 AS jsonb)) as is_meaningful`,
            [validContent, null]
        );

        console.log(`Content: "${validContent}"`);
        console.log(`Blocks: NULL`);
        console.log(`is_meaningful: ${result.rows[0].is_meaningful}`);

        if (result.rows[0].is_meaningful === false) {
            console.log("CONFIRMED: has_meaningful_content returns FALSE when blocks are NULL, even if content is valid.");
        } else {
            console.log("DEBUNKED: has_meaningful_content returns TRUE?");
        }

    } catch (e) {
        console.error(e);
    } finally {
        process.exit(0);
    }
}

testSqlFunction();
