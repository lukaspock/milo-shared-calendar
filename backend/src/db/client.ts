import { SQL } from "bun";

const db = new SQL(process.env.DATABASE_URL!);

export default db;
