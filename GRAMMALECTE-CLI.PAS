Program GRAMMALECTE_CLI;
{ Autonomous French checker. Turbo Pascal 7 / Free Pascal (-Mtp).
  No external dictionary, include file or unit is needed.
  This is an independent, deliberately limited implementation of the CLI,
  not a port of the upstream Grammalecte engine or its linguistic database.
  Input and reports: UTF-8. Positions: zero-based Unicode code points,
  end exclusive; paragraphs here correspond to physical input lines.
  Limits are checked, never silently truncated. Exit: 0 success, 2 failure. }
{$IFDEF FPC}
 {$MODE TP}{$H-}
{$ENDIF}
{$R+}

Uses Dos;

Const
 MaxLine = 16000;
 MaxTokens = 500;
 MaxErrors = 500;
 MaxWords = 2400;

Type
 TWord = String[80];
 PWord = ^TWord;
 TToken = Record
  Raw, Key: TWord;
  First, Last: Word;
 End;
 TError = Record
  First, Last: Word;
  Spelling: Boolean;
  Rule: String[32];
  MessageText: String[160];
  Suggestion: TWord;
 End;
 PToken = ^TToken;
 PError = ^TError;

Var
 Source, Report: Text;
 FileName, OutName, Arg: String;
 Line: Array[1..MaxLine] Of Char;
 Tokens: Array[1..MaxTokens] Of PToken;
 Errors: Array[1..MaxErrors] Of PError;
 Dictionary: Array[1..MaxWords] Of PWord;
 LineLen, TokenCount, ErrorCount, WordCount: Word;
 Paragraph, TotalGrammar, TotalSpelling: LongInt;
 ToFile, Json, OnlyErrors, FirstParagraph: Boolean;
 I, IOCode: Integer;

Procedure Fail(S: String);Begin
  { stderr is not available in Turbo Pascal; errors precede any JSON output
    for command line / open failures. Runtime I/O errors use exit status 2. }
 WriteLn('Erreur: ', S);
 Halt(2)
End;

Function Fold(S: String): TWord;
Var
 P: Integer;
 C, D: Byte;
 R: TWord;
Begin
 R := ''; P := 1;
 While P <= Length(S) Do Begin
  C := Ord(S[P]);
  If (C >= 65) And (C <= 90) Then C := C + 32;
  If (C = 195) And (P < Length(S)) Then Begin
   Inc(P); D := Ord(S[P]);
   Case D Of
   128..134,160..166: C := 97;
   135,167: C := 99;
   136..139,168..171: C := 101;
   140..143,172..175: C := 105;
   146..150,178..182: C := 111;
   153..156,185..188: C := 117;
   157,189,191: C := 121;
   Else C := 0
  End
 End;
 If C <> 0 Then R := R + Chr(C);
 Inc(P)
End;
Fold := R
End;

Procedure Words(S: String);
Var
 P, B: Integer;
Begin
 P := 1;
 While P <= Length(S) Do Begin
  While (P <= Length(S)) And (S[P] = ' ') Do Inc(P);
  B := P;
  While (P <= Length(S)) And (S[P] <> ' ') Do Inc(P);
  If P > B Then Begin
   If WordCount = MaxWords Then Fail('lexique interne trop grand');
   Inc(WordCount); New(Dictionary[WordCount]); Dictionary[WordCount]^ := Copy(S, B, P-B)
  End
 End
End;

Procedure InitDictionary;
Var
 A, B: Integer;
 W: TWord;
Begin
 WordCount := 0;
 Words(
 'a à ai aie aies ait as au aux avec avant après assez aussi autant autre autres aucun aucune alors ainsi aller allons allez allez-vous');
 Words(
 'avoir avons avez avaient avais avait ayant eu eue eus eues aurai auras aura aurons aurez auront aurais aurait auraient');
 Words(
 'être suis es est sommes êtes sont étais était étions étiez étaient été serai seras sera serons serez seront serait seraient sois soit soient');
 Words(
 'bonjour bonsoir salut merci oui non peut-être voici voilà bien mal mieux très trop peu plus moins beaucoup tout tous toute toutes');
 Words(
 'ce cet cette ces celui celle ceux celles ceci cela ça de du des le la les un une et ou où mais donc or ni car si sinon');
 Words(
 'je tu il elle on nous vous ils elles me te se moi toi soi lui leur leurs mon ma mes ton ta tes son sa ses notre nos votre vos');
 Words(
 'dans sur sous par pour sans entre vers chez contre depuis pendant durant malgré selon parmi devant derrière');
 Words(
 'ne pas jamais rien personne aucun seulement encore déjà toujours souvent parfois quelquefois maintenant aujourd’hui demain hier');
 Words(
 'ici là ailleurs partout ensemble quand comme comment pourquoi parce que qui quoi dont lequel laquelle lesquels lesquelles');
 Words(
 'chaque plusieurs quelques quelque même mêmes certain certains certaine certaines tel telle tels telles');
 Words(
 'puis peux peut pouvons pouvez peuvent pouvais pouvait pouvaient pu dois doit devons devez doivent devrait devraient dû');
 Words(
 'fais fait faisons faites font faisais faisait faisaient faire faisant vais vas va vont aller viens vient venons venez viennent venir');
 Words(
 'veux veut voulons voulez veulent vouloir sais sait savons savez savent savoir vois voit voyons voyez voient voir');
 Words(
 'dis dit disent dire donne donnes donnent donner prends prend prendre pense penses pensent penser aime aimes aiment aimer');
 Words(
 'parle parles parlent parlons parlez parler mange manges mangent mangeons mangez manger travaille travaillent travailler');
 Words(
 'habite habitent habiter regarde regardent regarder trouve trouvent trouver semble semblent sembler reste restent rester');
 Words(
 'faut fallait fallait falloir pleut pleuvoir existe existent existez écrit écris écrivent écrire lire lis lit lisent lu lue');
 Words(
 'bonjour monde texte textes fichier fichiers phrase phrases mot mots mot-clé exemple exemples erreur erreurs faute fautes');
 Words(
 'français française françaises langue langues grammaire orthographe correction correcteur correcteurs dictionnaire rapport résultat résultats');
 Words(
 'petit petits petite petites grand grands grande grandes bon bons bonne bonnes mauvais mauvaise mauvaises beau beaux belle belles');
 Words(
 'nouveau nouveaux nouvelle nouvelles vieux vieille vieilles jeune jeunes joli jolis jolie jolies heureux heureuse heureuses');
 Words(
 'chat chats chatte chattes chien chiens chienne chiennes animal animaux cheval chevaux oiseau oiseaux poisson poissons');
 Words(
 'maison maisons jardin jardins voiture voitures livre livres école écoles classe classes élève élèves enfant enfants');
 Words(
 'homme hommes femme femmes fille filles garçon garçons ami amis amie amies famille familles père mère frère soeur sœur');
 Words(
 'jour jours nuit nuits matin matins soir soirs semaine semaines mois année années an ans heure heures minute minutes temps');
 Words(
 'eau pain vin lait café thé pomme pommes fruit fruits repas table tables chaise chaises porte portes fenêtre fenêtres');
 Words(
 'ville villes pays rue rues route routes chemin chemins train trains avion avions vélo bateau bateaux travail travaux bureau bureaux');
 Words(
 'ordinateur ordinateurs programme programmes information informations système systèmes données document documents ligne lignes');
 Words(
 'important importants importante importantes possible possibles impossible impossibles simple simples difficile difficiles facile faciles');
 Words(
 'vrai vrais vraie vraies faux fausse fausses premier premiers première premières dernier derniers dernière dernières');
 Words(
 'rouge rouges vert verts verte vertes bleu bleus bleue bleues blanc blancs blanche blanches noir noirs noire noires');
 Words(
 'gentil gentils gentille gentilles content contents contente contentes heureux heureuse triste tristes fatigué fatigués fatiguée fatiguées');
 Words(
 'deux trois quatre cinq six sept huit neuf dix onze douze cent cents mille million millions zéro');
 Words(
 'chose choses problème problèmes question questions réponse réponses raison raisons besoin besoins point points cas manière façon');
 Words(
 'début fin suite partie parties place places côté côtés droit droite gauche centre nord sud ouest');
 Words(
 'vraiment simplement rapidement lentement facilement correctement notamment également cependant pourtant ensuite enfin plutôt presque');
 Words(
 'attention accord accords nom noms verbe verbes sujet sujets adjectif adjectifs pluriel singulier féminin masculin');
 Words(
 'merci monsieur madame bon bonne journée bienvenue bientôt revoir plaisir santé vie mort amour paix');
 Words(
 'pris prise compris comprendre appris apprendre ouvert ouvrir fermé fermer reçu recevoir envoyé envoyer utilisé utiliser');
 Words(
 'besoin envie peur raison tort cours course histoire histoires musique film films photo photos image images');
 Words('l d j c n s t m qu jusqu lorsqu puisqu aujourd hui est-ce');
  { Sort once; binary lookup preserves accented dictionary spellings. }
 For A := 2 To WordCount Do Begin
  W := Dictionary[A]^; B := A-1;
  While B > 0 Do Begin
   If Fold(Dictionary[B]^) <= Fold(W) Then Break;
   Dictionary[B+1]^ := Dictionary[B]^; Dec(B)
  End;
  Dictionary[B+1]^ := W
 End
End;

Function Known(W: TWord): Boolean;
Var
 L, H, M: Integer;
 K: TWord;
Begin
 L := 1; H := WordCount; Known := False;
 While L <= H Do Begin
  M := (L+H) Div 2; K := Fold(Dictionary[M]^);
  If W = K Then Begin
   Known := True; Exit
  End;
  If W < K Then H := M-1 Else L := M+1
 End
End;

Function Distance(A, B: TWord): Integer;
Var
 Prev, Curr: Array[0..80] Of Byte;
 X,Y,V: Integer;
Begin
 For X := 0 To Length(B) Do Prev[X] := X;
 For Y := 1 To Length(A) Do Begin
  Curr[0] := Y;
  For X := 1 To Length(B) Do Begin
   V := Prev[X-1]; If A[Y] <> B[X] Then Inc(V);
   If Prev[X]+1 < V Then V := Prev[X]+1;
   If Curr[X-1]+1 < V Then V := Curr[X-1]+1;
   Curr[X] := V
  End;
  Prev := Curr
 End;
 Distance := Prev[Length(B)]
End;

Function Suggest(W: TWord): TWord;
Var
 N, D, Best: Integer;
 K, R: TWord;
Begin
 R := ''; Best := 3;
 If Length(W) < 5 Then Best := 2;
 For N := 1 To WordCount Do Begin
  K := Fold(Dictionary[N]^);
  If Abs(Length(K)-Length(W)) < Best Then Begin
   D := Distance(W,K);
   If D < Best Then Begin
    Best := D; R := Dictionary[N]^
   End
  End
 End;
 Suggest := R
End;

Function ColumnAt(P: Word): Word;
Var
 N, C: Word;
Begin
 C := 0;
 For N := 1 To P-1 Do    If (Ord(Line[N]) And $C0) <> $80 Then Inc(C);
 ColumnAt := C
End;

Procedure AddError(A,B: Word; Spell: Boolean; Rule, Msg, Sugg: String);Begin
 If ErrorCount = MaxErrors Then Fail('trop de diagnostics sur une ligne');
 Inc(ErrorCount);
 With Errors[ErrorCount]^ Do Begin
  First := ColumnAt(A); Last := ColumnAt(B);
  Spelling := Spell;
  MessageText := Msg; Suggestion := Sugg
 End;
 Errors[ErrorCount]^.Rule := Rule;
 If Spell Then Inc(TotalSpelling) Else Inc(TotalGrammar)
End;

Function Letter(P: Word): Boolean;
Var
 C: Byte;
Begin
 C := Ord(Line[P]);
 Letter := (C In [65..90,97..122]) Or (C >= 128)
End;

Procedure Tokenize;
Var
 P,B: Word;
 S: TWord;
Begin
 P := 1; TokenCount := 0;
 While P <= LineLen Do Begin
    { UTF-8 punctuation: apostrophe, spaces, dashes, quotation marks. }
  If (P+2 <= LineLen) And (Ord(Line[P])=$E2) And
  (Ord(Line[P+1])=$80) And (Ord(Line[P+2]) In [$90..$BF]) Then Inc(P,3) Else
  If (P+1 <= LineLen) And (Ord(Line[P])=$C2) And
  (Ord(Line[P+1])=$A0) Then Inc(P,2) Else
  If Letter(P) Then Begin
   B := P; S := '';
   While P <= LineLen Do Begin
    If Not Letter(P) Then Break;
    If (Ord(Line[P])=$E2) Or (Ord(Line[P])=$C2) Then Break;
    If Length(S) = 80 Then Fail('mot de plus de 80 octets');
    S := S + Line[P]; Inc(P)
   End;
   If P = B Then Inc(P)
    Else
   Begin
    If TokenCount = MaxTokens Then Fail('plus de 500 mots sur une ligne');
    Inc(TokenCount);
    With Tokens[TokenCount]^ Do Begin
     Raw := S; Key := Fold(S); First := B; Last := P
    End
   End
  End Else Inc(P)
 End
End;

Function InList(W,S: String): Boolean;Begin
 InList := Pos(' '+W+' ', ' '+S+' ') > 0
End;

Procedure Grammar;
Var
 N,P: Word;
 W, Prev, Correction: TWord;
 Adjacent: Boolean;
Begin
 For N := 1 To TokenCount Do Begin
  W := Tokens[N]^.Key; Prev := ''; Adjacent := False;
  If N > 1 Then Begin
   Prev := Tokens[N-1]^.Key; Adjacent := True;
   For P := Tokens[N-1]^.Last To Tokens[N]^.First-1 Do        If Line[P] <>
   ' ' Then Adjacent := False
  End;
  Correction := '';
  If W='sa' Then Begin
   If (N<TokenCount) Then        If InList(Tokens[N+1]^.Key,'va marche fonctionne suffit')
   Then Correction := 'ça'
  End;
  If Adjacent Then Begin
   If (Prev='je') And (W='suis') Then Begin
   End
   Else If (Prev='je') And (W='suit') Then Correction := 'suis' Else
   If (Prev='tu') And InList(W,'est ai a') Then Correction := 'es' Else
   If InList(Prev,'il elle on') And InList(W,'es et') Then Correction := 'est' Else
   If (Prev='ils') And InList(W,'son est') Then Correction := 'sont' Else
   If (Prev='elles') And InList(W,'son est') Then Correction := 'sont' Else
   If (Prev='nous') And InList(W,'sont somme') Then Correction := 'sommes' Else
   If (Prev='vous') And InList(W,'est etes') And (Tokens[N]^.Raw<>'êtes')
   Then Correction := 'êtes' Else
   If (Prev='je') And InList(W,'manges parles aimes') Then Correction := Copy(W,1,
   Length(W)-1)
   Else If (Prev='tu') And InList(W,'mange parle aime') Then Correction := W+'s' Else
   If InList(Prev,'il elle on') And InList(W,'manges parles aimes')
   Then Correction := Copy(W,1,Length(W)-1) Else
   If InList(Prev,'ils elles') And InList(W,'mange parle aime') Then Correction := W+
   'nt';
   If (W=Prev) And Not InList(W,'nous vous') Then        AddError(Tokens[N]^.First,
   Tokens[N]^.Last,False,'REPETITION','Mot repete.', '');
   If InList(Prev,'les des ces mes tes ses nos vos leurs') And
   InList(W,'chat chien maison voiture livre enfant fille garcon ami pomme')
   Then        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'ACCORD_NOMBRE',
   'Un pluriel est attendu apres ce determinant.',W+'s');
   If InList(Prev,'la une cette ma ta sa') And InList(W,'chat chien garcon livre')
   Then        AddError(Tokens[N-1]^.First,Tokens[N-1]^.Last,False,'ACCORD_GENRE',
   'Verifier le genre du determinant.','');
   If (W='a') And InList(Prev,'vais vas va allons allez vont aller') Then        AddError(
   Tokens[N]^.First,Tokens[N]^.Last,False,'A_ACCENT',
   'La preposition prend un accent grave.','à');
   If (N>2) And InList(Tokens[N-2]^.Key,'les des ces mes tes ses nos vos leurs') And
   InList(Prev,'chats chiens enfants filles garcons amis voitures maisons') And
   InList(W,'mange parle aime') Then        AddError(Tokens[N]^.First,Tokens[N]^.Last,
   False,'ACCORD_VERBE',
   'Un verbe au pluriel est attendu avec ce sujet.',W+'nt');
   If InList(Prev,'maison voiture fille pomme') And
   InList(W,'petit grand joli vert bleu noir') Then        AddError(Tokens[N]^.First,
   Tokens[N]^.Last,False,'ACCORD_ADJECTIF',
   'Verifier le feminin de cet adjectif.',W+'e')
  End;
  If Correction <> '' Then      AddError(Tokens[N]^.First,Tokens[N]^.Last,False,
  'CONFUSION','Verifier la conjugaison ou cet homophone.',Correction)
 End;
 For P := 1 To LineLen Do Begin
  If (Line[P] In [',','.']) And (P>1) Then      If Line[P-1]=' ' Then AddError(P-1,P,
  False,'ESPACE_AVANT','Espace superflue avant la ponctuation.','');
  If (Line[P] In [',',';',':','!','?']) And (P<LineLen) Then      If Line[P+
  1] In ['a'..'z','A'..'Z'] Then        AddError(P+1,P+1,False,'ESPACE_APRES',
  'Espace attendue apres la ponctuation.',' ')
 End
End;

Procedure Spelling;
Var
 N: Word;
 W, S: TWord;
Begin
 For N := 1 To TokenCount Do Begin
  W := Tokens[N]^.Key; S := '';
  If W='bonjours' Then S := 'bonjour' Else
  If W='beaucoups' Then S := 'beaucoup' Else
  If W='malgres' Then S := 'malgré' Else
  If W='parmis' Then S := 'parmi' Else
  If W='biensur' Then S := 'bien sûr' Else
  If Tokens[N]^.Raw='francais' Then S := 'français' Else
  If Tokens[N]^.Raw='ecole' Then S := 'école' Else
  If Tokens[N]^.Raw='tres' Then S := 'très' Else
  If Tokens[N]^.Raw='etre' Then S := 'être' Else
  If Tokens[N]^.Raw='deja' Then S := 'déjà' Else
  If Tokens[N]^.Raw='apres' Then S := 'après' Else
  If Tokens[N]^.Raw='bientot' Then S := 'bientôt';
  If S<>'' Then      AddError(Tokens[N]^.First,Tokens[N]^.Last,True,'ORTHOGRAPHE',
  'Orthographe a verifier.',S)
  Else If Not Known(W) Then Begin
   S := Suggest(W);
   AddError(Tokens[N]^.First,Tokens[N]^.Last,True,'ORTHOGRAPHE',
   'Mot absent du lexique embarque (nom propre ou mot rare possible).',S)
  End
 End
End;

Procedure JString(S: String);
Var
 N: Integer;
 C: Byte;
Const
 Hex: String[16] = '0123456789abcdef';
Begin
 Write(Report,'"');
 For N := 1 To Length(S) Do Begin
  C := Ord(S[N]);
  Case C Of
  34: Write(Report,'\"');
  92: Write(Report,'\\');
  0..31: Write(Report,'\u00',Hex[C Div 16+1],Hex[C Mod 16+1]);
  Else Write(Report,S[N])
 End
End;
Write(Report,'"')
End;

Procedure EmitErrors(Spell: Boolean);
Var
 N: Word;
 First: Boolean;
Begin
 First := True; Write(Report,'[');
 For N := 1 To ErrorCount Do If Errors[N]^.Spelling=Spell Then Begin
  If Not First Then Write(Report,','); First := False;
  With Errors[N]^ Do Begin
   Write(Report,'{"nStart":',Errors[N]^.First,',"nEnd":',Last,',"sRuleId":');
   JString(Rule); Write(Report,',"sMessage":'); JString(MessageText);
   Write(Report,',"aSuggestions":[');
   If Suggestion<>'' Then JString(Suggestion);
   Write(Report,']}')
  End
 End;
 Write(Report,']')
End;

Procedure EmitLine;
Var
 N: Word;
Begin
 If OnlyErrors And (ErrorCount=0) Then Exit;
 If Json Then Begin
  If Not FirstParagraph Then WriteLn(Report,','); FirstParagraph := False;
  Write(Report,'{"iParagraph":',Paragraph,',"lGrammarErrors":');
  EmitErrors(False); Write(Report,',"lSpellingErrors":'); EmitErrors(True);
  Write(Report,'}')
 End Else
 Begin
  Write(Report,Paragraph,': ');
  For N := 1 To LineLen Do Write(Report,Line[N]);
  WriteLn(Report);
  For N := 1 To ErrorCount Do With Errors[N]^ Do Begin
   Write(Report,'  ',First+1,'-',Last,' [',Rule,'] ',MessageText);
   If Suggestion<>'' Then Write(Report,' Suggestion: ',Suggestion);
   WriteLn(Report)
  End
 End
End;

Procedure Help;Begin
 WriteLn(
 'GRAMMALECTE-CLI - Cette commande permet de lancer le correcteur francais autonome (lexique limite).');
 WriteLn;
 WriteLn('Syntaxe: grammalecte-cli -f fichier.txt [-j] [-owe]');
 WriteLn('         grammalecte-cli -ff fichier.txt [-j] [-owe]');
 WriteLn;
 WriteLn('  -f, --file          Analyser un fichier UTF-8 vers la console');
 WriteLn('  -ff, --file_to_file Creer fichier.res.txt (ou .res.json avec -j)');
 WriteLn('  -j, --json         Rapport JSON avec suggestions');
 WriteLn('  -owe, --only_when_errors  Omettre les lignes sans erreurs');
 WriteLn('  -h, -?, --help     Aide');
 WriteLn('  --version         Version');
 WriteLn;
 WriteLn('Suggestions incluses aussi dans le rapport texte.');
 WriteLn('Limites: 16000 octets, 500 mots et 500 diagnostics par ligne.');
 WriteLn('Lexique reduit: les mots inconnus ne sont pas necessairement fautifs.');
 WriteLn('Ce programme ne contient pas le moteur complet de Grammalecte.')
End;

Function ResultName(S: String): String;
Var
 N, DotAt: Integer;
Begin
 DotAt := 0;
 For N := Length(S) Downto 1 Do Begin
  If S[N] In ['\','/',':'] Then Break;
  If S[N]='.' Then Begin
   DotAt := N; Break
  End
 End;
 If DotAt>0 Then Delete(S,DotAt,Length(S)-DotAt+1);
 If Length(S)>244 Then Fail('nom du rapport trop long');
 If Json Then ResultName := S+'.res.json' Else ResultName := S+'.res.txt'
End;

Function UpperName(S: String): String;
Var
 N: Integer;
Begin
 For N := 1 To Length(S) Do S[N] := UpCase(S[N]);
 UpperName := S
End;

Procedure ReadLine;
Var
 C: Char;
 N, Need, B: Word;
 V, LowBound, HighBound: Byte;
Begin
 LineLen := 0;
 While Not Eof(Source) Do Begin
  Read(Source,C);
  If C=#10 Then Break;
  If C<>#13 Then Begin
   If LineLen=MaxLine Then Fail('ligne de plus de 16000 octets');
   Inc(LineLen); Line[LineLen] := C
  End
 End;
 If (Paragraph=1) And (LineLen>=3) Then    If (Ord(Line[1])=$EF) And (Ord(Line[2])=$BB)
 And (Ord(Line[3])=$BF) Then Begin
  For N := 4 To LineLen Do Line[N-3] := Line[N]; Dec(LineLen,3)
 End;
 N := 1;
 While N<=LineLen Do Begin
  V := Ord(Line[N]); Need := 0; LowBound := $80; HighBound := $BF;
  If V<$80 Then Begin
   If (V<32) And (V<>9) Then Fail('caractere de controle dans le fichier')
  End
  Else If V In [$C2..$DF] Then Need := 1 Else
  If V In [$E0..$EF] Then Begin
   Need := 2; If V=$E0 Then LowBound := $A0;
   If V=$ED Then HighBound := $9F
  End
  Else If V In [$F0..$F4] Then Begin
   Need := 3; If V=$F0 Then LowBound := $90;
   If V=$F4 Then HighBound := $8F
  End Else Fail('encodage UTF-8 invalide');
  If N+Need>LineLen Then Fail('sequence UTF-8 incomplete');
  For B := 1 To Need Do Begin
   V := Ord(Line[N+B]);
   If (V<LowBound) Or (V>HighBound) Then Fail('encodage UTF-8 invalide');
   LowBound := $80; HighBound := $BF
  End;
  Inc(N,Need+1)
 End
End;

BEGIN
 FileName := ''; ToFile := False; Json := False; OnlyErrors := False;
 I := 1;
 If ParamCount=0 Then Begin
  Help; Halt(0)
 End;
 While I<=ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg='-h') Or (Arg='-?') Or (Arg='--help') Then Begin
   Help; Halt(0)
  End
  Else If Arg='--version' Then Begin
   WriteLn('GRAMMALECTE-CLI Pascal 1.0 (independant)'); Halt(0)
  End
  Else If (Arg='-j') Or (Arg='--json') Then Json := True Else
  If (Arg='-owe') Or (Arg='--only_when_errors') Then OnlyErrors := True Else
  If (Arg='-f') Or (Arg='--file') Or (Arg='-ff') Or (Arg='--file_to_file') Then Begin
   If FileName<>'' Then Fail('un seul fichier est autorise');
   ToFile := (Arg='-ff') Or (Arg='--file_to_file');
   Inc(I); If I>ParamCount Then Fail('nom de fichier manquant');
   FileName := ParamStr(I)
  End Else Fail('option inconnue: '+Arg);
  Inc(I)
 End;
 If FileName='' Then Fail('utiliser -f ou -ff suivi du fichier');
 Assign(Source,FileName); {$I-} Reset(Source); {$I+}
 If IOResult<>0 Then Fail('impossible de lire '+FileName);
 If ToFile Then Begin
  OutName := ResultName(FileName);
  If UpperName(OutName)=UpperName(FileName) Then Fail(
  'le rapport remplacerait le fichier source');
  Assign(Report,OutName)
 End Else Assign(Report,'');
  {$I-} Rewrite(Report); {$I+}
 If IOResult<>0 Then Fail('impossible de creer le rapport');
 For I := 1 To MaxTokens Do New(Tokens[I]);
 For I := 1 To MaxErrors Do New(Errors[I]);
 InitDictionary;
 Paragraph := 0; TotalGrammar := 0; TotalSpelling := 0; FirstParagraph := True;
 If Json Then WriteLn(Report,
 '{"sVersion":"pascal-1.0","sLangCode":"fr","sScope":"limited-embedded-lexicon","data":[')
 ;
 While Not Eof(Source) Do Begin
  Inc(Paragraph); ReadLine; Tokenize; ErrorCount := 0;
  Grammar; Spelling; EmitLine
 End;
 If Json Then WriteLn(Report,'],"nGrammarErrors":',TotalGrammar,',"nSpellingErrors":',
 TotalSpelling,'}')
 Else WriteLn(Report,TotalGrammar,' erreur(s) grammaticale(s), ',TotalSpelling,
 ' mot(s) inconnu(s).');
 Close(Source);
  {$I-} Close(Report); {$I+} IOCode := IOResult;
 If IOCode<>0 Then Halt(2)
END.
