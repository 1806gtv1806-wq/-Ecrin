# ÉCRIN — Application native : développement du 9 novembre 2026

Base : dépôt `1806gtv1806-wq/-Ecrin`, commit `27869ab7846d3e2d01b73b7764c47c94847c1a71`.

## Code ajouté et relié

- Organic : choix explicite d’un fichier audio, copie temporaire dans l’espace de l’app, lecture/pause, position, volume et minuteur de concentration. Pause lors des interruptions, de la sortie de l’écran et du passage en arrière-plan. Les copies de travail sont supprimées à la sortie ; l’original n’est jamais modifié. Aucun catalogue ou abonnement musical connecté.
- Fusion : choix d’au moins deux mémoires, assemblage local avec titres et dates, édition du brouillon, partage de texte et création d’une nouvelle mémoire. Sources conservées ; détection de doublon exact avant création. Ce parcours n’est pas une synthèse IA.
- Verso : Photos et Fichiers, extraction locale d’images, PDF et texte UTF-8, correction du texte puis partage/enregistrement dans MemoryOS. Aucun téléversement IA automatique.
- MemoryOS : l’import utilise le même extracteur PDF/image/texte, hors du thread d’interface. Pour un PDF mixte, chaque page sans texte sélectionnable passe dans Vision. Limites explicites : 30 Mo et 100 pages. Annulation et erreurs sans ajout d’un texte partiel.
- Démarrage : si le magasin CloudKit existant ne peut pas être ouvert, proposer de réessayer ou d’ouvrir une mémoire locale persistante séparée. Aucun basculement silencieux, aucune migration, aucun indicateur de synchronisation inventé.
- Einstein : arrêt du micro avant la demande IA ; arrêt de la lecture avant dictée ; activation explicite de la session audio pour la synthèse ; erreur audio visible ; une réponse tardive ne relance pas la voix après sortie d’écran ; la question enregistrée correspond à la réponse reçue.
- Accessibilité : Reduce Motion désactive la transition de navigation et la pulsation d’Einstein. Libellés natifs pour les nouveaux contrôles audio.

## Vérification effectuée ici

Les 21 fichiers Swift de Sources ont été analysés avec la grammaire tree-sitter-swift : aucune erreur syntaxique repérée. Ce contrôle n’effectue ni résolution des types ni vérification des API/SDK. Contrôle de différence et des fichiers reliés effectué.

Six tests XCTest sont fournis pour l’extracteur : fidélité UTF-8, encodage invalide, taille limite, OCR d’un PDF rasterisé, refus des PDF trop longs et annulation. Ils n’ont PAS été exécutés ici. L’environnement ne dispose ni de Swift, ni de Xcode, ni des SDK Apple. Aucune compilation, signature, installation, exécution sur simulateur/appareil ou publication TestFlight n’est revendiquée. Aucun workflow n’a été lancé.

## Vérifications restantes avant RC

1. Compiler et exécuter les XCTest sur le SDK iOS avec le module Ecrin-iOS et sa cible de tests. Vérifier en particulier les API SwiftData/Observation et les delegates audio.
2. Sur iPad Pro et iPhone Air, importer un PDF mixte texte/scans, annuler une extraction, corriger le texte et le retrouver après relance.
3. Fusionner deux mémoires, corriger le brouillon, enregistrer une fois et vérifier que les deux sources restent inchangées.
4. Lire un M4A/MP3/WAV, chercher dans la piste, changer le volume, interrompre l’audio puis terminer une session de concentration. Vérifier casque et haut-parleur.
5. Refuser iCloud : choisir le mode local, quitter et rouvrir la même mémoire locale, puis vérifier que le magasin iCloud reste distinct.
6. Avec un service IA configuré ou Apple Intelligence compatible, dicter, demander, écouter et interrompre Einstein ; quitter pendant une réponse réseau et vérifier l’absence de lecture tardive.
7. Tester VoiceOver, Dynamic Type et Reduce Motion sur les appareils physiques.

## Limites conservées

Les assets originaux UX Master 3.0 et le véritable cube SceneKit ne figurent pas dans ce dépôt. Le cube de façade, les proportions, les fonds et le dock existants ne sont pas redessinés par ce changement ; ils ne sont pas certifiés conformes au Master. Il faut récupérer le référentiel original pour cette conformité. La navigation iPhone en 12 pages horizontales, la synchronisation CloudKit réelle et le Dual Screen complet restent à développer/valider. Le transfert Einstein existant reste un transfert de texte confirmé, pas une réplication du micro. Les services externes IA exigent leur configuration ; aucune clé ni capacité externe n’est inventée.
