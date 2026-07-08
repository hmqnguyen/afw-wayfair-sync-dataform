// sources.js — khai báo 3 raw tables (C# AfwWayfairSync ghi). Dataform chỉ đọc.
const rawDataset = (dataform.projectConfig.vars && dataform.projectConfig.vars.raw_dataset)
  ? dataform.projectConfig.vars.raw_dataset : "afw_wayfair_raw";
const rawTables = ["raw_wayfair_orders", "raw_wayfair_inventory_castlegate", "raw_wayfair_inventory_dropship"];
rawTables.forEach(name => {
  declare({ database: dataform.projectConfig.defaultDatabase, schema: rawDataset, name });
});
