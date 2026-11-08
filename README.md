# Ecrin

Ecrin est une application de mémoire intelligente, de tri et de synthèse pour organiser des idées, analyser du texte et produire des fiches structurées.

## Fonctionnalités

- Mémoire centrale avec indexation intelligente
- Analyse de texte et génération de notices
- IA générative compatible OpenAI ou Ollama
- Interface visuelle inspirée d’un cube rotatif
- Tri et fusion d’informations
- API REST pour intégration et extension

## Stack

- Python 3.12+
- FastAPI
- Jinja / HTML static + CSS + JavaScript
- Support IA : OpenAI API ou Ollama local

## Démarrage rapide

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Puis ouvrir : http://localhost:8000/ui

## IA générative

### Option 1 : OpenAI

```bash
export OPENAI_API_KEY=votre_cle
export OPENAI_MODEL=gpt-4o-mini
```

### Option 2 : Ollama local

```bash
export OLLAMA_BASE_URL=http://localhost:11434
export OLLAMA_MODEL=llama3.1
```

Si aucune variable d’environnement n’est définie, l’application utilise un moteur local de fallback basé sur les mots-clés et le résumé heuristique.

## API

- GET /api/health
- GET /api/notes
- POST /api/notes
- POST /api/scan
- POST /api/classify
- POST /api/generate (`text` + `kind`: `notice` ou `guide`)
- GET /api/ai/config — état du moteur et indication de l’authentification
- POST /api/ask — conversation via OpenAI ou Ollama, authentification requise
- POST /api/projects/generate — génération d’une archive ZIP, authentification requise

Les routes conversationnelles et de génération de projets nécessitent un jeton partagé entre l’app et le serveur. Avant de les utiliser, créez un jeton aléatoire (par exemple `openssl rand -hex 32`), définissez-le dans `ECRIN_API_TOKEN` côté serveur, puis saisissez la même valeur dans **Réglages IA → Accès sécurisé à l’Atelier IA**. L’app la conserve dans le trousseau Apple. Ne publiez pas le serveur sans HTTPS et sans un jeton privé. Ce mécanisme est une authentification partagée minimale; il ne remplace ni des comptes utilisateurs, ni une limitation de débit, ni une protection anti-abus.

## Application Apple native

Le projet SwiftUI se trouve dans `apple/`. La cible iOS est réglée pour les tests sur iPhone et iPad; une cible macOS est également définie. Il propose une mémoire synchronisée avec la base CloudKit privée, le tri sélectif, l’analyse locale d’images (texte et catégories visuelles) et la connexion au serveur IA FastAPI.

La façade native comprend maintenant un cube central et un dock commun en matériaux SwiftUI translucides, compatibles avec la cible iOS 17. MemoryOS, NOVA, Einstein et les réglages sont accessibles depuis cette navigation; Organic, Fusion et Verso restent des espaces de présentation, sans fonctions métier implémentées à ce stade. Cette première intégration ne remplace pas encore les assets du référentiel UX Master 3.0.

MemoryOS propose une recherche locale dans les titres, textes, catégories et tags. La création de mémoire accepte les PDF contenant du texte sélectionnable, les fichiers texte UTF-8 et les images choisies. L’OCR et l’analyse visuelle des images sont traités sur l’appareil avec Vision. Un classement IA reste une proposition que l’utilisateur doit appliquer; les contenus strictement identiques sont signalés avant l’enregistrement. L’OCR des pages numérisées contenues dans un PDF, l’import de dossiers et la suppression sécurisée de fichiers ne sont pas encore pris en charge.

Einstein permet de saisir ou dicter une question, d’obtenir une réponse via le serveur IA configuré, de l’écouter puis d’enregistrer l’échange dans MemoryOS. La dictée requiert les autorisations microphone et reconnaissance vocale Apple; l’interruption arrête la lecture audio. Einstein ne déclenche pas encore d’actions métier à la voix.

Quand Einstein est ouvert sur plusieurs appareils proches, l’app peut proposer un transfert local chiffré de la question et de la réponse vers l’un d’eux. L’utilisateur confirme l’envoi sur l’appareil source puis la reprise sur l’appareil destinataire; aucun transfert n’est appliqué avant ces validations. La détection repose sur MultipeerConnectivity/Bonjour et peut demander l’autorisation d’accès au réseau local. Les deux appareils doivent avoir ÉCRIN ouvert au premier plan et être à proximité. Le transfert ne réplique pas l’état du microphone, la lecture audio ni un historique plus large.

NOVA permet de dicter une note, corriger la transcription, l’enregistrer dans MemoryOS et rechercher dans les transcriptions enregistrées. La capture utilise le même service vocal Apple qu’Einstein et s’arrête en quittant l’écran.

Sur un Mac avec Xcode et [XcodeGen](https://github.com/yonaskolb/XcodeGen) installés :

```bash
cd apple
xcodegen generate
open Ecrin.xcodeproj
```

Dans Xcode, associez les deux cibles à votre équipe Apple, activez iCloud/CloudKit et créez ou sélectionnez le conteneur `iCloud.com.ecrin.app`. Configurez ensuite l’URL HTTPS publique du serveur dans l’onglet **Réglages IA**. Les clés des fournisseurs IA restent côté serveur.

Le client natif est un socle initial : le classement, la génération de notices/guides et la synchronisation CloudKit sont câblés. Les rappels programmés utilisent les notifications locales; autorisez les notifications sur chaque appareil. Une date de rappel se synchronise avec la mémoire, mais chaque appareil doit programmer sa propre notification. L’import d’un dossier iCloud Drive existant reste à développer.

### Compilation Xcode sur GitHub Actions

Le workflow `.github/workflows/apple-build.yml` compile manuellement l’app pour le simulateur iOS sur un runner macOS, avec une durée maximale de 20 minutes par exécution. Il ne se lance pas automatiquement sur les push afin d’éviter une consommation inattendue. Lancez-le depuis **Actions → Apple build → Run workflow** après avoir envoyé le workflow sur GitHub. Cette limite par exécution ne constitue pas un plafond mensuel de 500 minutes; configurez votre budget dans les paramètres de facturation GitHub, car le quota et la facturation macOS dépendent du forfait et du dépôt.
