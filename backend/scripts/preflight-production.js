#!/usr/bin/env node

require("dotenv").config();
const { productionPreflight } = require("../src/config/productionPreflight");

const result = productionPreflight(process.env);
console.log(JSON.stringify(result, null, 2));
if (!result.ok) process.exitCode = 1;
