import { prisma } from "../src/prisma";

async function main() {
  await prisma.exchangeRate.upsert({
    where: {
      baseCurrency_quoteCurrency: {
        baseCurrency: "USD",
        quoteCurrency: "INR"
      }
    },
    update: {
      rate: 83.42,
      cheaperPercentage: 2.3,
      asOf: new Date()
    },
    create: {
      baseCurrency: "USD",
      quoteCurrency: "INR",
      rate: 83.42,
      cheaperPercentage: 2.3,
      asOf: new Date()
    }
  });

  console.log("Seeded exchange rate defaults for RemitFlow.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
