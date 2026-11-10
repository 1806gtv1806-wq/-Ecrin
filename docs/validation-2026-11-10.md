# ÉCRIN — validation du 10 novembre 2026

Révision examinée : 3d0c693d7bd1f6d5a70e99ce0a6809393d7b8347.

## Tests exécutés

- `python -m unittest discover -s tests -v` : 7 tests réussis. Authentification, refus de jeton invalide, fournisseur absent, transmission des consignes et de l’historique, export ZIP et rejet des chemins traversants. Les fournisseurs sont simulés ; aucun appel payant.
- `python -m compileall -q app tests` : réussi.
- Python 3.12 ; requests 2.32.3 installé dans un dossier temporaire. Les autres bibliothèques proviennent du runtime et ne reproduisent pas exactement requirements.txt. Un avertissement de dépréciation TestClient/httpx apparaît.
- Build simulateur antérieur db6c447 : réussi, run 42861858184. Ce résultat précède les modifications IA locale.
- Build de la révision IA locale : run 42863911990, dernier état observé en attente de runner macOS.

## Blocages et limites

- Aucun test XCTest ou XCUITest dans l’arborescence examinée.
- Pas de Xcode ni Swift dans le runtime Linux de validation : pas d’exécution native locale.
- Aucun essai physique iPad/iPhone : micro, transcription, lecture audio, CloudKit, sauvegarde après redémarrage, permissions et accessibilité non validés.
- Foundation Models dépend de la disponibilité du modèle sur appareil ; aucune réponse réelle testée.
- Les appels distants AIService sont bloqués ; classement, documents et archives attendent une implémentation locale. Les écrans conservent des références au serveur qui doivent être corrigées.
- Le démarrage dépend encore de l’ouverture du conteneur SwiftData/CloudKit, sans repli local établi.
- Einstein demeure intégré alors que le périmètre demandé le sépare d’ÉCRIN.
- Les tests backend ne certifient pas le client SwiftUI ni le respect du mode gratuit dans tous les composants.

## Conclusion

Validation partielle. Application non certifiée entièrement fonctionnelle et non prête à publier sur la seule base de ces contrôles. Aucun envoi TestFlight.
