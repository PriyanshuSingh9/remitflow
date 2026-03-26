import { prisma } from "../src/prisma";

async function main() {
  console.log("No seed data configured yet for RemitFlow.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
