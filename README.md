# CORRECTEUR-0
Suite de commandes écrites en Pascal (Turbo Pascal ou Free Pascal) pour la correction linguistique.

<h2>Liste des fichiers</h2>

Voici la liste des différentes commandes proposées dans CORRECTEUR-0 :

<table>
  <tr>
    <th>Nom</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><b>GRAMMALECTE-CLI.PAS</b></td>
    <td>Cette commande permet de vérifier l'orthographe et certaines règles de grammaire d'un fichier de texte français, avec des suggestions et un rapport texte ou JSON.</td>
  </tr>
</table>

<h2>Remarques</h2>

<ul>
  <li>GRAMMALECTE-CLI.PAS : implémentation indépendante et partielle de l'interface de Grammalecte, avec un lexique embarqué et des règles de conjugaison, d'accord, d'homophones, de répétition et de ponctuation. Elle ne contient pas le moteur complet de Grammalecte. Les mots inconnus peuvent être des mots français corrects ou des noms propres ; les suggestions ne garantissent pas la correction du texte.</li>
  <li>Vérification d'un fichier : <code>GRAMMALECTE-CLI -f texte.txt</code>. Création d'un rapport avec suggestions : <code>GRAMMALECTE-CLI -ff texte.txt</code>, qui produit <code>texte.res.txt</code>. Le fichier source n'est pas modifié.</li>
  <li>Rapport JSON : <code>GRAMMALECTE-CLI -f texte.txt -j</code> pour l'afficher, ou <code>GRAMMALECTE-CLI -ff texte.txt -j</code> pour créer <code>texte.res.json</code>. Les suggestions disponibles sont incluses dans les deux formats.</li>
  <li>Paramètres disponibles : <code>-f</code> ou <code>--file</code>, <code>-ff</code> ou <code>--file_to_file</code>, <code>-j</code> ou <code>--json</code>, <code>-owe</code> ou <code>--only_when_errors</code> pour omettre les lignes sans erreurs, ainsi que <code>--help</code> et <code>--version</code>.</li>
  <li>Les fichiers d'entrée et les rapports utilisent UTF-8, avec ou sans BOM en entrée. Le source Pascal est entièrement ASCII : les caractères accentués des chaînes sont représentés par leurs octets UTF-8 sous forme de codes numériques. La recherche orthographique neutralise la casse et plusieurs accents ; seules certaines omissions d'accents sont explicitement détectées.</li>
  <li>Chaque ligne physique correspond à un paragraphe. Dans le JSON, <code>data</code> contient <code>iParagraph</code>, <code>lGrammarErrors</code> et <code>lSpellingErrors</code>. Les positions <code>nStart</code> et <code>nEnd</code> sont exprimées en caractères Unicode à partir de zéro, avec une borne de fin exclue. Le rapport texte utilise des colonnes à partir de un.</li>
  <li>Limites par ligne : 16 000 octets UTF-8, 500 mots et 500 diagnostics. Un mot peut occuper au plus 80 octets. Le code de sortie est 0 pour une analyse terminée, même avec des diagnostics, et 2 pour une erreur d'arguments, d'ouverture ou de limite de traitement. Une erreur de traitement peut laisser un rapport incomplet.</li>
  <li>La seule unité utilisée est <code>Dos</code>. Aucun dictionnaire externe ni fichier d'inclusion n'est nécessaire. La compilation et les tests ont été effectués avec Free Pascal en mode Turbo Pascal ; Turbo Pascal 7 reste à vérifier directement. Sous DOS, copier le source sous un nom au format 8.3 avant compilation.</li>
</ul>

<h2>Compilation</h2>

Pour compiler GRAMMALECTE-CLI.PAS avec Free Pascal en mode Turbo Pascal :

<pre><b>fpc</b> -Mtp GRAMMALECTE-CLI.PAS</pre>

Pour essayer la compilation avec Turbo Pascal, après avoir copié le source sous le nom GRAMCLI.PAS :

<pre><b>tpc</b> GRAMCLI.PAS</pre>

<h2>Tests</h2>

<ul>
  <li>Le script suivant compile le programme et vérifie les rapports, les suggestions, les positions Unicode, les entrées invalides et les limites de traitement. Il contrôle aussi que le source est ASCII et que ses lignes ne dépassent pas 120 octets.</li>
</ul>

<pre>powershell -ExecutionPolicy Bypass -File tests/grammalecte-cli.ps1</pre>

<h2>Licence</h2>

<ul>
  <li>Le code source est publié sous la licence <a href="LICENSE">MIT</a>.</li>
</ul>
