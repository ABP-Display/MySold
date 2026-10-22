// Instance-specific information replaces the hosted edition's legal notices.
String? selfHostedLegal(String key, String language) {
  if (key != 'legal_terms_full' && key != 'privacy_policy_full') return null;
  if (language == 'fr') {
    return key == 'legal_terms_full'
        ? '''Conditions d’utilisation de MySold

MySold est un outil de suivi personnel des comptes, opérations et investissements. Il ne réalise aucune opération bancaire et ne fournit pas de conseil financier. Les simulations et projections sont indicatives.

Cette instance est exploitée par la personne qui l’héberge. L’administrateur est responsable de son accès, de sa maintenance, des sauvegardes et des informations de contact à communiquer aux utilisateurs. Le créateur du logiciel n’héberge pas automatiquement les données des instances tierces.

Vous êtes responsable des données saisies ou importées et de la protection de vos identifiants. Une sauvegarde est conseillée avant un import ou une suppression. La suppression du compte depuis l’application est irréversible pour les données actives ; la politique de conservation des sauvegardes dépend de l’administrateur.

L’utilisation du logiciel est soumise à la licence fournie dans son dépôt. La consultation du code ne confère pas un droit général de redistribution ou de commercialisation. Les composants tiers conservent leurs licences respectives.

Le service peut être interrompu. Dans les limites du droit applicable, le logiciel est fourni sans garantie de disponibilité ni d’exactitude des prévisions. Vos droits légaux impératifs restent applicables.'''
        : '''Confidentialité de votre instance MySold

Les données de profil, comptes, catégories, investissements, transactions et seuils budgétaires sont enregistrées dans la base PostgreSQL de cette instance. Aucun compte Firebase, Google ou service d’analyse externe n’est nécessaire au fonctionnement de MySold. L’accès par navigateur transmet les données au serveur choisi par l’administrateur.

L’administrateur de cette instance est votre interlocuteur pour les questions de confidentialité, de conservation et de sauvegarde. Il doit fournir ses coordonnées et, selon son usage, les informations réglementaires complémentaires. La présence de cette notice ne constitue pas à elle seule une certification de conformité au RGPD.

Les mots de passe sont hachés côté serveur. Un cookie de session nécessaire à la connexion est utilisé. Le navigateur conserve certaines préférences visuelles et de notification. Le PIN verrouille l’interface et les écrans sensibles ; il ne chiffre pas la base de données et ne remplace pas votre mot de passe. Le mode discret masque l’affichage des montants.

Vous pouvez exporter vos données, restaurer un export compatible et supprimer votre compte depuis cette page. La suppression enlève le compte, ses données actives et ses sessions. Les copies de sauvegarde sont gérées séparément par l’administrateur, qui doit définir leur durée de conservation et leur procédure de purge.

Les notifications du navigateur sont facultatives. Les vérifications budgétaires se font lorsque l’application est ouverte ; aucun service de notification push externe n’est utilisé. Les exports sont téléchargés sur votre appareil et doivent être protégés comme toute donnée financière. La connexion au serveur doit être sécurisée par HTTPS hors utilisation locale.''';
  }
  return key == 'legal_terms_full'
      ? '''MySold Terms of Use

MySold tracks personal accounts, transactions and investments. It does not execute banking operations or provide financial advice. Forecasts are estimates.

This instance is operated by its administrator, who manages access, maintenance, backups and user contact information. The software author does not automatically host third-party instance data. You are responsible for your entries, imports and credentials. Export your data before importing or deleting an account.

Account deletion removes active data irreversibly. Backup retention is managed separately by the administrator. The repository license governs use of the software; source availability does not grant unrestricted redistribution or commercial rights. Third-party components retain their own licenses.

The software is provided without a guarantee of uninterrupted service or accurate forecasts, to the extent permitted by law. Mandatory statutory rights remain unaffected.'''
      : '''MySold Instance Privacy Notice

Profiles, accounts, categories, investments, transactions and budget thresholds are stored in this instance’s PostgreSQL database. MySold does not require Firebase, Google authentication or an external analytics service. Your browser communicates with the server selected by the instance administrator.

The administrator is your contact for privacy, retention and backups and must provide contact details and any additional legally required information. This notice alone does not certify GDPR compliance.

Passwords are hashed on the server. A necessary session cookie supports login. Your browser stores display and notification preferences. The PIN is an interface lock; it does not encrypt the database or replace your password. Privacy mode hides displayed amounts.

You can export and restore compatible data and delete your account. Deletion removes the account, active data and sessions. Backup copies have a separate retention and purge policy determined by the administrator.

Browser notifications are optional. Budget checks run while the application is open; there is no external push service. Protect downloaded exports as financial records. Use HTTPS outside local development.''';
}
