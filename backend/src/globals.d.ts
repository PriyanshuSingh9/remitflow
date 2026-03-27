declare const process: {
  env: Record<string, string | undefined>;
  exitCode?: number;
};

declare module "express";
declare module "cors";
declare module "jsonwebtoken";
