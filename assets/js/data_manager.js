const PORT = 8080;
const BASE_DATA_PATH = "./data/";

async function saveData(category, data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const filename = `${category}_${timestamp}.json`;
  const response = await fetch("/save_data.php", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ category, filename, data })
  });
  return await response.json();
}

async function listFiles(category) {
  const res = await fetch(`/list_data.php?category=${category}`);
  return await res.json();
}

async function loadData(category, filename) {
  const res = await fetch(`/load_data.php?category=${category}&file=${filename}`);
  return await res.json();
}

function formToJSON(formId) {
  const form = document.getElementById(formId);
  if (!form) return {};
  const formData = new FormData(form);
  const obj = {};
  formData.forEach((v, k) => obj[k] = v);
  obj["更新日時"] = new Date().toLocaleString("ja-JP");
  return obj;
}
