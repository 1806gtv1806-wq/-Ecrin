# ÉCRIN — Atelier vivant
## Spécification produit — Einstein, assistant IA interactif

**Statut :** export de cadrage produit
**Périmètre :** assistant transversal Einstein sur iPhone et iPad
**Révision :** 2

## 1. Vision

Einstein est le compagnon IA animé au cœur d’ÉCRIN. Il accompagne l’utilisateur dans son travail et ses idées, comprend le contexte de la conversation, aide à réfléchir et peut réaliser des actions dans les univers ÉCRIN lorsque l’utilisateur le lui demande.

Einstein doit donner une impression de présence, d’attention et de continuité. Il peut reconnaître le ton émotionnel d’un échange et y répondre avec tact, sans prétendre être humain, éprouver réellement des émotions ou remplacer un professionnel.

La référence à un assistant animé sert à exprimer le niveau de présence et d’interactivité souhaité. Einstein doit avoir une identité, une voix, un langage visuel et des animations originaux. Aucun personnage, modèle, nom, dialogue ou asset d’un produit tiers ne doit être reproduit.

## 2. Principes d’expérience

- **Conversation naturelle :** texte et voix, tours de parole compréhensibles, possibilité de préciser ou de corriger.
- **Écoute visible :** l’interface distingue clairement l’écoute, la transcription, le raisonnement, la réponse audio, la pause et l’erreur.
- **Interruption immédiate :** l’utilisateur peut arrêter l’écoute et interrompre la réponse vocale.
- **Contexte utile et maîtrisé :** Einstein peut s’appuyer sur les documents et notes autorisés, en indiquant les sources utilisées quand elles sont disponibles.
- **Actions confirmées :** avant de créer, modifier, déplacer, partager ou supprimer un contenu, Einstein décrit l’action et demande confirmation. Une copie est vérifiée avant toute suppression éventuelle.
- **Soutien émotionnel honnête :** ton empathique et non jugeant, sans diagnostic, manipulation, dépendance affective ni affirmation d’émotions vécues.
- **Transparence :** distinguer les faits des suggestions et signaler l’incertitude ou l’indisponibilité d’un service.
- **Contrôle utilisateur :** accès aux réglages de voix, mémoire, confidentialité et préférences conversationnelles.

## 3. Modes d’accompagnement

### Coach

Einstein aide l’utilisateur à clarifier un objectif, découper un travail en étapes, identifier un prochain petit pas ou faire un bilan. Il pose des questions courtes plutôt que de présumer des besoins.

### Assistant de travail

Einstein aide à résumer, rédiger, organiser et retrouver les informations. Il peut préparer une action pour MemoryOS, NOVA ou un autre univers, puis en demander la validation avant exécution.

### Compagnon de réflexion

Einstein peut aider à explorer une idée, proposer des pistes et reformuler le propos. Il reste explicite sur les limites de ses réponses et évite de présenter une hypothèse comme un fait.

Les modes modifient le style et les outils proposés; ils ne constituent pas des personnalités séparées et ne changent pas les règles de consentement ou de sécurité.

## 4. Interaction vocale

### États visibles

1. **Prêt :** aucune capture active.
2. **Demande d’autorisation :** explication claire avant l’accès au microphone ou à la reconnaissance vocale.
3. **Écoute :** indicateur animé lié à une capture réelle; commande d’arrêt toujours disponible.
4. **Transcription :** texte provisoire visible et corrigeable avant envoi si l’utilisateur le souhaite.
5. **Traitement :** demande envoyée au fournisseur configuré; possibilité d’annuler lorsque techniquement possible.
6. **Réponse :** texte affiché et, si la lecture audio est activée, voix synchronisée avec l’état réel du lecteur.
7. **Interruption :** arrêt immédiat de la synthèse vocale et retour à un état prêt.
8. **Erreur :** explication localisée, cause utile lorsque connue et action de reprise explicite.

L’indicateur de microphone ne doit jamais afficher une écoute si aucune capture audio n’est active. Les transitions d’état sont accessibles aux technologies d’assistance et restent compréhensibles sans animation.

### Contraintes de la première version

- Dictée française via les API Apple Speech, après autorisation.
- Lecture des réponses françaises avec AVSpeechSynthesizer.
- Requêtes de conversation via un endpoint serveur dédié.
- Aucune clé fournisseur intégrée à l’application cliente.
- L’état « réponse en cours » doit correspondre à la synthèse réellement active; sa fin ou son interruption doit être détectée.

La conversation multi-tours avec historique envoyé au modèle, le réveil mains libres, la détection avancée d’émotions vocales et le traitement audio entièrement en continu ne sont pas inclus par défaut. Ils demandent une décision produit, une conception de confidentialité et une validation technique distinctes.

## 5. Présence visuelle et animation

Einstein a une présence animée originale intégrée au langage visuel ÉCRIN : surfaces et éclairages Liquid Glass, profondeur maîtrisée, espace dégagé et palette cohérente avec l’Atelier vivant.

Les animations communiquent une intention réelle :

- présence calme en attente;
- mouvement d’écoute uniquement pendant la capture effective;
- transition de traitement lorsque la requête est envoyée;
- réponse animée pendant la voix ou l’affichage du texte;
- pause ou interruption immédiatement perceptible;
- erreur visible sans animation qui masque le message.

### Direction visuelle retenue

Le visuel de référence d’Einstein est prêt. Sa personnalité est **curieuse, malicieuse et expressive**. Trois attitudes constituent les états visuels principaux :

1. **Écoute** — Einstein est attentif pendant une capture audio réellement active.
2. **Réflexion** — Einstein traite la demande après la fin de la capture ou l’envoi du texte.
3. **Eurêka !** — Einstein met en valeur une réponse ou une découverte; l’expression ne doit pas laisser croire que la réponse est forcément exacte.

Le modèle 3D, son rig et ses animations restent à créer. Le modèle devra préserver l’identité du visuel fourni et décliner les trois attitudes. Les animations doivent rester liées à l’état réel de l’assistant, respecter les préférences d’accessibilité et pouvoir être réduites ou désactivées.

### Éléments restant à confirmer

- intégration des fichiers sources du visuel de référence et spécification de leurs formats;
- modèle 3D original, rig, contrôleurs d’expression et animations;
- voix et charte audio définitives;
- degré de personnalisation de l’apparence;
- animation de l’accueil et emplacement sur le cube ou dans un panneau dédié;
- adaptation de la présence aux formats iPad et iPhone.

Aucun de ces choix ne doit être considéré comme validé avant réception des références UX Master et confirmation du propriétaire du produit.

## 6. Relais entre les univers ÉCRIN

Einstein est transversal, mais les modules métier restent propriétaires de leurs données et actions :

- **MemoryOS :** rechercher et résumer les mémoires autorisées, préparer un classement ou une notice.
- **NOVA :** capturer ou retrouver des idées et transcriptions selon les permissions accordées.
- **Organic :** proposer un lancement de session de concentration si cette action est définie et disponible.
- **Fusion :** aider à rapprocher ou transformer des contenus via les fonctions effectivement implémentées.
- **Verso :** explorer les vues complémentaires une fois son périmètre défini.

Einstein ne doit ni prétendre déclencher une fonction inexistante ni afficher un succès avant confirmation du module concerné. Toute action expose son résultat, son échec et les éventuelles étapes suivantes.

## 7. Architecture cible

- **Présentation SwiftUI :** conversation, présence animée, panneau iPad et présentation compacte iPhone.
- **Navigation :** AppRouter commun et états de présentation explicitement définis.
- **Assistant :** orchestration de conversation, états d’interaction, modes Coach/Travail/Réflexion.
- **Audio Apple :** services isolés pour capture, Speech et synthèse AVFoundation; autorisations et interruptions gérées explicitement.
- **ExternalAPIManager :** transport réseau central, connecteurs indépendants, authentification serveur, erreurs typées et observabilité sans fuite du contenu privé.
- **Mémoire :** accès contrôlé aux données SwiftData/CloudKit et à la recherche; provenance des informations préservée lorsque possible.
- **Actions métier :** protocoles ou commandes appartenant aux modules, avec confirmation explicite pour les opérations à effet de bord.

Les clés OpenAI, Ollama ou de tout autre fournisseur demeurent côté serveur. Les paramètres de consentement, les règles de conservation des conversations et le choix d’envoyer ou non le contexte doivent être définis avant une mise en production.

## 8. Parcours principal

1. L’utilisateur ouvre Einstein depuis le dock ou l’univers actif.
2. Einstein affiche son état réel et permet une question écrite ou dictée.
3. L’utilisateur voit et peut corriger la transcription.
4. Einstein répond par écrit; la lecture audio peut être lancée ou interrompue.
5. Si une réponse mobilise des documents, Einstein indique les éléments consultés lorsque cette provenance est disponible.
6. Si une action dans ÉCRIN est proposée, Einstein la résume et demande confirmation.
7. Le module concerné exécute l’action et retourne un résultat explicite.
8. L’utilisateur peut enregistrer l’échange ou modifier les préférences de mémoire.

## 9. Critères d’acceptation produit

- Chaque état microphone/audio correspond à l’état effectif du service.
- L’écoute, le traitement, la réponse, l’interruption et l’erreur sont distincts visuellement et accessibles.
- L’utilisateur peut interrompre la synthèse vocale par une action directe.
- Les permissions sont demandées au moment utile, avec les explications système requises.
- Aucune action modifiant des données ne s’exécute sans autorisation explicite.
- L’assistant ne revendique pas de sentiments vécus et ne présente pas un diagnostic comme un fait.
- En l’absence de serveur ou de réseau, Einstein explique la limitation et préserve le texte saisi.
- Le même parcours est utilisable avec VoiceOver et au clavier, et s’adapte aux tailles d’écran sans dépendre de l’animation.
- Les promesses de produit correspondent aux capacités réellement intégrées.

## 10. Limites de l’export

Ce document cadre la vision et les critères de conception. Le visuel de référence est déclaré prêt; son fichier n’est pas inclus dans le dépôt consulté. Le modèle 3D, le rig et les animations restent à créer. Le document ne valide pas le design final, les performances audio, le comportement sur appareils réels, la disponibilité réseau, la configuration CloudKit ou les capacités du fournisseur IA. Ces points exigent une compilation Xcode, des essais sur iPhone/iPad et les accès et ressources correspondants.
