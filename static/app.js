const titleInput = document.getElementById('titleInput');
const contentInput = document.getElementById('contentInput');
const resultBox = document.getElementById('resultBox');
const notesList = document.getElementById('notesList');
const analysisStatus = document.getElementById('analysisStatus');
const analysisStatusText = document.getElementById('analysisStatusText');
const actionButtons = [...document.querySelectorAll('.actions button')];

function setAnalysisStatus(message, state) {
  analysisStatusText.textContent = message;
  analysisStatus.dataset.state = state;
}

async function runAction(button, pendingMessage, successMessage, action) {
  actionButtons.forEach((actionButton) => {
    actionButton.disabled = true;
  });
  button.setAttribute('aria-busy', 'true');
  resultBox.setAttribute('aria-busy', 'true');
  setAnalysisStatus(pendingMessage, 'loading');

  try {
    const completed = await action();
    if (completed !== false) {
      setAnalysisStatus(successMessage, 'success');
    }
  } catch (error) {
    console.error(error);
    resultBox.className = 'result-box';
    resultBox.textContent = 'Une erreur est survenue. Réessayez dans un instant.';
    setAnalysisStatus('Une erreur est survenue.', 'error');
  } finally {
    actionButtons.forEach((actionButton) => {
      actionButton.disabled = false;
    });
    button.removeAttribute('aria-busy');
    resultBox.removeAttribute('aria-busy');
  }
}

async function apiFetch(path, options = {}) {
  const response = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });

  if (!response.ok) {
    throw new Error(`Erreur HTTP: ${response.status}`);
  }

  return response.json();
}

function renderResult(data) {
  resultBox.classList.remove('empty');
  const keywords = (data.keywords || []).map((item) => `<span class="tag">${item}</span>`).join('');
  const tags = (data.tags || []).map((item) => `<span class="tag">${item}</span>`).join('');

  resultBox.innerHTML = `
    <p><strong>Catégorie :</strong> ${data.category || 'général'}</p>
    <p><strong>Résumé :</strong> ${data.summary || 'Aucun résumé.'}</p>
    <div><strong>Mots clés :</strong> ${keywords || 'Aucun'}</div>
    <div style="margin-top: 8px;"><strong>Tags :</strong> ${tags || 'Aucun'}</div>
  `;
}

async function scanContent() {
  const text = contentInput.value.trim();
  if (!text) {
    resultBox.className = 'result-box empty';
    resultBox.textContent = 'Saisissez du texte pour lancer l’analyse.';
    setAnalysisStatus('Ajoutez une note pour continuer.', 'error');
    return false;
  }

  const response = await apiFetch('/api/scan', {
    method: 'POST',
    body: JSON.stringify({ text }),
  });
  renderResult(response);
  return true;
}

async function classifyContent() {
  const text = contentInput.value.trim();
  if (!text) {
    resultBox.className = 'result-box empty';
    resultBox.textContent = 'Ajoutez un texte pour classifier.';
    setAnalysisStatus('Ajoutez une note pour continuer.', 'error');
    return false;
  }

  const response = await apiFetch('/api/classify', {
    method: 'POST',
    body: JSON.stringify({ text }),
  });
  renderResult(response);
  return true;
}

async function saveNotice() {
  const title = titleInput.value.trim() || 'Nouvelle notice';
  const text = contentInput.value.trim();
  if (!text) {
    resultBox.className = 'result-box empty';
    resultBox.textContent = 'Le contenu est vide, ajoutez un texte avant de créer une notice.';
    setAnalysisStatus('Ajoutez une note pour continuer.', 'error');
    return false;
  }

  const response = await apiFetch('/api/notes', {
    method: 'POST',
    body: JSON.stringify({ title, content: text }),
  });

  const item = response.item;
  resultBox.classList.remove('empty');
  resultBox.innerHTML = `
    <p><strong>Notice créée :</strong> ${item.title}</p>
    <p>${item.summary}</p>
    <div class="note-tags">${(item.tags || []).map((tag) => `<span class="tag">${tag}</span>`).join('')}</div>
  `;
  return loadNotes();
}

async function loadNotes() {
  try {
    const response = await apiFetch('/api/notes');
    notesList.innerHTML = '';

    if (!response.items.length) {
      notesList.innerHTML = '<div class="note-item"><p>Aucune notice pour le moment.</p></div>';
      return true;
    }

    response.items.forEach((note) => {
      const el = document.createElement('article');
      el.className = 'note-item';
      el.innerHTML = `
        <h4>${note.title}</h4>
        <p>${note.summary}</p>
        <div class="note-tags">${(note.tags || []).map((tag) => `<span class="tag">${tag}</span>`).join('')}</div>
      `;
      notesList.appendChild(el);
    });
    return true;
  } catch (error) {
    console.error(error);
    notesList.textContent = 'Impossible de charger vos notices pour le moment.';
    setAnalysisStatus('Collection indisponible.', 'error');
    return false;
  }
}

document.getElementById('scanBtn').addEventListener('click', (event) => {
  runAction(event.currentTarget, 'Analyse en cours…', 'Analyse terminée.', scanContent);
});
document.getElementById('classifyBtn').addEventListener('click', (event) => {
  runAction(event.currentTarget, 'Classement en cours…', 'Classement terminé.', classifyContent);
});
document.getElementById('saveBtn').addEventListener('click', (event) => {
  runAction(event.currentTarget, 'Création en cours…', 'Notice enregistrée.', saveNotice);
});

loadNotes();
