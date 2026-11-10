# ÉCRIN — Architecture de référence

Date : 10 novembre 2026.

## Périmètre décidé

ÉCRIN est une application iPad Pro et iPhone Air comprenant l’accueil et son cube 3D à six faces, Memory, NOVA, Organic, Fusion et Verso. Einstein est un projet indépendant : application, dépôt, données et feuille de route distincts. Aucune connexion interprojets n’est implicite.

## Références visuelles

Les nouveaux Masters validés priment sur les anciennes maquettes. Préserver les proportions, reflets, chrome transparent, Liquid Glass et docks. Les six JPEG de référence n’étaient pas accessibles lors de cette revue : aucune fidélité visuelle n’a été vérifiée. iPhone : 12 pages horizontales, sans défilement vertical. Scan Memory : page dédiée, sans éléments de l’interface Memory, cube et documents fidèles aux références.

## Architecture cible — proposée

| Couche | Responsabilité |
|---|---|
| App | Démarrage, navigation, cycle de vie, permissions |
| DesignSystem | Ressources des nouveaux Masters et composants communs |
| Features/Home | Cube et navigation vers les cinq modules |
| Features/Memory | Import, OCR, classement, doublons, recherche |
| Features/NOVA | Capture et transcription audio |
| Features/Organic | Audio et ambiances |
| Features/Fusion | Périmètre métier à préciser |
| Features/Verso | Périmètre métier à préciser |
| Domain | Modèles et règles indépendants des vues |
| Services | Fichiers, Vision, Speech, audio, recherche, notifications |
| Persistence | Stockage local, journal et synchronisation CloudKit |
| Diagnostics | États, erreurs et preuves de validation |

Les vues déclenchent des opérations via les services et affichent leur résultat réel. Les modules ne dépendent pas des vues des autres modules. Les services partagés ne doivent pas dépendre d’Einstein. L’IA externe reste optionnelle ; aucune clé ou dépense n’est créée par cette architecture.

## Données et sûreté

Parcours cible Memory : import → analyse → proposition → validation → copie → vérification → confirmation. Aucune suppression avant copie vérifiée. Doublons par SHA-256, journal et restauration à implémenter et tester. Un état « synchronisé » nécessite une preuve de synchronisation. Prévoir un fonctionnement local et des états CloudKit distincts, plutôt qu’un blocage global de l’application.

## État observé dans main

Revue limitée au README, à l’arborescence et aux fichiers AppRouter.swift et EcrinApp.swift. Aucun test exécuté, aucune compilation ou validation sur appareil.

- Le dépôt comporte un client SwiftUI dans apple/, un serveur Python dans app/ et une interface web dans static/.
- AppRouter.swift déclare encore la destination einstein.
- apple/Sources/EinsteinView.swift et exports/ATELIER-Export-AI/Einstein-Specification.md sont présents ; leur existence ne prouve pas leur fonctionnement.
- Le README annonce Organic, Fusion et Verso comme espaces de présentation sans fonctions métier ; cette déclaration n’a pas été vérifiée par des tests.
- EcrinApp.swift initialise SwiftData avec le conteneur CloudKit privé iCloud.com.memoryos.brain26. En cas d’échec d’initialisation, il affiche un écran d’indisponibilité ; aucun repli local n’apparaît dans ce fichier.
- La présence des workflows de build et TestFlight ne prouve pas une compilation ou une distribution réussie.

## Séparation Einstein — travail restant

1. Identifier le dépôt Einstein de destination et vérifier que son code y est conservé.
2. Relever toutes les références Einstein dans navigation, vues, services, documentation et configuration de build.
3. Distinguer les services utiles à ÉCRIN, notamment Speech pour NOVA, des composants propres à Einstein.
4. Préparer une modification isolée retirant l’accès Einstein d’ÉCRIN et adaptant sa documentation ; préserver les données existantes.
5. Compiler et vérifier accueil, navigation, Memory, NOVA et stockage avant intégration.

Cette revue ne retire, ne déplace ni ne copie aucun code Einstein.

## Ordre de réalisation

1. Séparer le périmètre Einstein et stabiliser le démarrage local.
2. Terminer un parcours Memory complet et vérifiable.
3. Vérifier NOVA puis développer les fonctions propres aux trois autres modules.
4. Appliquer les nouveaux Masters accessibles et vérifier les adaptations par appareil.
5. Tester CloudKit, puis la continuité et le Dual Screen.
6. Vérifier VoiceOver, Dynamic Type et Reduce Motion.

Chaque livraison indique séparément : prévu, implémenté, simulé, compilé, réellement testé ou non vérifié, avec preuve et prochaine vérification.
