program GrammalecteCLI;
{ Autonomous French checker. Turbo Pascal 7 / Free Pascal (-Mtp).
  No external dictionary, include file or unit is needed.
  This is an independent, deliberately limited implementation of the CLI,
  not a port of the upstream Grammalecte engine or its linguistic database.
  Input and reports: UTF-8. Positions: zero-based Unicode code points,
  end exclusive; paragraphs here correspond to physical input lines.
  Limits are checked, never silently truncated. Exit: 0 success, 2 failure. }
{$IFDEF FPC}{$MODE TP}{$H-}{$ENDIF}
{$R+}
uses Dos;
const
  MaxLine = 16000;
  MaxTokens = 500;
  MaxErrors = 500;
  MaxWords = 2400;
type
  TWord = string[80];
  PWord = ^TWord;
  TToken = record
    Raw, Key: TWord;
    First, Last: Word;
  end;
  TError = record
    First, Last: Word;
    Spelling: Boolean;
    Rule: string[32];
    MessageText: string[160];
    Suggestion: TWord;
  end;
  PToken = ^TToken;
  PError = ^TError;
var
  Source, Report: Text;
  FileName, OutName, Arg: string;
  Line: array[1..MaxLine] of Char;
  Tokens: array[1..MaxTokens] of PToken;
  Errors: array[1..MaxErrors] of PError;
  Dictionary: array[1..MaxWords] of PWord;
  LineLen, TokenCount, ErrorCount, WordCount: Word;
  Paragraph, TotalGrammar, TotalSpelling: LongInt;
  ToFile, Json, OnlyErrors, FirstParagraph: Boolean;
  I, IOCode: Integer;

procedure Fail(S: string);
begin
  { stderr is not available in Turbo Pascal; errors precede any JSON output
    for command line / open failures. Runtime I/O errors use exit status 2. }
  WriteLn('Erreur: ', S);
  Halt(2)
end;

function Fold(S: string): TWord;
var P: Integer; C, D: Byte; R: TWord;
begin
  R := ''; P := 1;
  while P <= Length(S) do begin
    C := Ord(S[P]);
    if (C >= 65) and (C <= 90) then C := C + 32;
    if (C = 195) and (P < Length(S)) then begin
      Inc(P); D := Ord(S[P]);
      case D of
        128..134,160..166: C := 97;
        135,167: C := 99;
        136..139,168..171: C := 101;
        140..143,172..175: C := 105;
        146..150,178..182: C := 111;
        153..156,185..188: C := 117;
        157,189,191: C := 121;
      else C := 0
      end
    end;
    if C <> 0 then R := R + Chr(C);
    Inc(P)
  end;
  Fold := R
end;

procedure Words(S: string);
var P, B: Integer;
begin
  P := 1;
  while P <= Length(S) do begin
    while (P <= Length(S)) and (S[P] = ' ') do Inc(P);
    B := P;
    while (P <= Length(S)) and (S[P] <> ' ') do Inc(P);
    if P > B then begin
      if WordCount = MaxWords then Fail('lexique interne trop grand');
      Inc(WordCount); New(Dictionary[WordCount]); Dictionary[WordCount]^ := Copy(S, B, P-B)
    end
  end
end;

procedure InitDictionary;
var A, B: Integer; W: TWord;
begin
  WordCount := 0;
  Words('a à ai aie aies ait as au aux avec avant après assez aussi autant autre autres aucun aucune alors ainsi aller allons allez allez-vous');
  Words('avoir avons avez avaient avais avait ayant eu eue eus eues aurai auras aura aurons aurez auront aurais aurait auraient');
  Words('être suis es est sommes êtes sont étais était étions étiez étaient été serai seras sera serons serez seront serait seraient sois soit soient');
  Words('bonjour bonsoir salut merci oui non peut-être voici voilà bien mal mieux très trop peu plus moins beaucoup tout tous toute toutes');
  Words('ce cet cette ces celui celle ceux celles ceci cela ça de du des le la les un une et ou où mais donc or ni car si sinon');
  Words('je tu il elle on nous vous ils elles me te se moi toi soi lui leur leurs mon ma mes ton ta tes son sa ses notre nos votre vos');
  Words('dans sur sous par pour sans entre vers chez contre depuis pendant durant malgré selon parmi devant derrière');
  Words('ne pas jamais rien personne aucun seulement encore déjà toujours souvent parfois quelquefois maintenant aujourd’hui demain hier');
  Words('ici là ailleurs partout ensemble quand comme comment pourquoi parce que qui quoi dont lequel laquelle lesquels lesquelles');
  Words('chaque plusieurs quelques quelque même mêmes certain certains certaine certaines tel telle tels telles');
  Words('puis peux peut pouvons pouvez peuvent pouvais pouvait pouvaient pu dois doit devons devez doivent devrait devraient dû');
  Words('fais fait faisons faites font faisais faisait faisaient faire faisant vais vas va vont aller viens vient venons venez viennent venir');
  Words('veux veut voulons voulez veulent vouloir sais sait savons savez savent savoir vois voit voyons voyez voient voir');
  Words('dis dit disent dire donne donnes donnent donner prends prend prendre pense penses pensent penser aime aimes aiment aimer');
  Words('parle parles parlent parlons parlez parler mange manges mangent mangeons mangez manger travaille travaillent travailler');
  Words('habite habitent habiter regarde regardent regarder trouve trouvent trouver semble semblent sembler reste restent rester');
  Words('faut fallait fallait falloir pleut pleuvoir existe existent existez écrit écris écrivent écrire lire lis lit lisent lu lue');
  Words('bonjour monde texte textes fichier fichiers phrase phrases mot mots mot-clé exemple exemples erreur erreurs faute fautes');
  Words('français française françaises langue langues grammaire orthographe correction correcteur correcteurs dictionnaire rapport résultat résultats');
  Words('petit petits petite petites grand grands grande grandes bon bons bonne bonnes mauvais mauvaise mauvaises beau beaux belle belles');
  Words('nouveau nouveaux nouvelle nouvelles vieux vieille vieilles jeune jeunes joli jolis jolie jolies heureux heureuse heureuses');
  Words('chat chats chatte chattes chien chiens chienne chiennes animal animaux cheval chevaux oiseau oiseaux poisson poissons');
  Words('maison maisons jardin jardins voiture voitures livre livres école écoles classe classes élève élèves enfant enfants');
  Words('homme hommes femme femmes fille filles garçon garçons ami amis amie amies famille familles père mère frère soeur sœur');
  Words('jour jours nuit nuits matin matins soir soirs semaine semaines mois année années an ans heure heures minute minutes temps');
  Words('eau pain vin lait café thé pomme pommes fruit fruits repas table tables chaise chaises porte portes fenêtre fenêtres');
  Words('ville villes pays rue rues route routes chemin chemins train trains avion avions vélo bateau bateaux travail travaux bureau bureaux');
  Words('ordinateur ordinateurs programme programmes information informations système systèmes données document documents ligne lignes');
  Words('important importants importante importantes possible possibles impossible impossibles simple simples difficile difficiles facile faciles');
  Words('vrai vrais vraie vraies faux fausse fausses premier premiers première premières dernier derniers dernière dernières');
  Words('rouge rouges vert verts verte vertes bleu bleus bleue bleues blanc blancs blanche blanches noir noirs noire noires');
  Words('gentil gentils gentille gentilles content contents contente contentes heureux heureuse triste tristes fatigué fatigués fatiguée fatiguées');
  Words('deux trois quatre cinq six sept huit neuf dix onze douze cent cents mille million millions zéro');
  Words('chose choses problème problèmes question questions réponse réponses raison raisons besoin besoins point points cas manière façon');
  Words('début fin suite partie parties place places côté côtés droit droite gauche centre nord sud ouest');
  Words('vraiment simplement rapidement lentement facilement correctement notamment également cependant pourtant ensuite enfin plutôt presque');
  Words('attention accord accords nom noms verbe verbes sujet sujets adjectif adjectifs pluriel singulier féminin masculin');
  Words('merci monsieur madame bon bonne journée bienvenue bientôt revoir plaisir santé vie mort amour paix');
  Words('pris prise compris comprendre appris apprendre ouvert ouvrir fermé fermer reçu recevoir envoyé envoyer utilisé utiliser');
  Words('besoin envie peur raison tort cours course histoire histoires musique film films photo photos image images');
  Words('l d j c n s t m qu jusqu lorsqu puisqu aujourd hui est-ce');
  { Sort once; binary lookup preserves accented dictionary spellings. }
  for A := 2 to WordCount do begin
    W := Dictionary[A]^; B := A-1;
    while B > 0 do begin
      if Fold(Dictionary[B]^) <= Fold(W) then Break;
      Dictionary[B+1]^ := Dictionary[B]^; Dec(B)
    end;
    Dictionary[B+1]^ := W
  end
end;

function Known(W: TWord): Boolean;
var L, H, M: Integer; K: TWord;
begin
  L := 1; H := WordCount; Known := False;
  while L <= H do begin
    M := (L+H) div 2; K := Fold(Dictionary[M]^);
    if W = K then begin Known := True; Exit end;
    if W < K then H := M-1 else L := M+1
  end
end;

function Distance(A, B: TWord): Integer;
var Prev, Curr: array[0..80] of Byte; X,Y,V: Integer;
begin
  for X := 0 to Length(B) do Prev[X] := X;
  for Y := 1 to Length(A) do begin
    Curr[0] := Y;
    for X := 1 to Length(B) do begin
      V := Prev[X-1]; if A[Y] <> B[X] then Inc(V);
      if Prev[X]+1 < V then V := Prev[X]+1;
      if Curr[X-1]+1 < V then V := Curr[X-1]+1;
      Curr[X] := V
    end;
    Prev := Curr
  end;
  Distance := Prev[Length(B)]
end;

function Suggest(W: TWord): TWord;
var N, D, Best: Integer; K, R: TWord;
begin
  R := ''; Best := 3;
  if Length(W) < 5 then Best := 2;
  for N := 1 to WordCount do begin
    K := Fold(Dictionary[N]^);
    if Abs(Length(K)-Length(W)) < Best then begin
      D := Distance(W,K);
      if D < Best then begin Best := D; R := Dictionary[N]^ end
    end
  end;
  Suggest := R
end;

function ColumnAt(P: Word): Word;
var N, C: Word;
begin
  C := 0;
  for N := 1 to P-1 do
    if (Ord(Line[N]) and $C0) <> $80 then Inc(C);
  ColumnAt := C
end;

procedure AddError(A,B: Word; Spell: Boolean; Rule, Msg, Sugg: string);
begin
  if ErrorCount = MaxErrors then Fail('trop de diagnostics sur une ligne');
  Inc(ErrorCount);
  with Errors[ErrorCount]^ do begin
    First := ColumnAt(A); Last := ColumnAt(B);
    Spelling := Spell; 
    MessageText := Msg; Suggestion := Sugg
  end;
  Errors[ErrorCount]^.Rule := Rule;
  if Spell then Inc(TotalSpelling) else Inc(TotalGrammar)
end;

function Letter(P: Word): Boolean;
var C: Byte;
begin
  C := Ord(Line[P]);
  Letter := (C in [65..90,97..122]) or (C >= 128)
end;

procedure Tokenize;
var P,B: Word; S: TWord;
begin
  P := 1; TokenCount := 0;
  while P <= LineLen do begin
    { UTF-8 punctuation: apostrophe, spaces, dashes, quotation marks. }
    if (P+2 <= LineLen) and (Ord(Line[P])=$E2) and
       (Ord(Line[P+1])=$80) and (Ord(Line[P+2]) in [$90..$BF]) then Inc(P,3)
    else if (P+1 <= LineLen) and (Ord(Line[P])=$C2) and
      (Ord(Line[P+1])=$A0) then Inc(P,2)
    else if Letter(P) then begin
      B := P; S := '';
      while P <= LineLen do begin
        if not Letter(P) then Break;
        if (Ord(Line[P])=$E2) or (Ord(Line[P])=$C2) then Break;
        if Length(S) = 80 then Fail('mot de plus de 80 octets');
        S := S + Line[P]; Inc(P)
      end;
      if P = B then Inc(P)
      else begin
        if TokenCount = MaxTokens then Fail('plus de 500 mots sur une ligne');
        Inc(TokenCount);
        with Tokens[TokenCount]^ do begin
          Raw := S; Key := Fold(S); First := B; Last := P
        end
      end
    end else Inc(P)
  end
end;

function InList(W,S: string): Boolean;
begin InList := Pos(' '+W+' ', ' '+S+' ') > 0 end;

procedure Grammar;
var N,P: Word; W, Prev, Correction: TWord; Adjacent: Boolean;
begin
  for N := 1 to TokenCount do begin
    W := Tokens[N]^.Key; Prev := ''; Adjacent := False;
    if N > 1 then begin
      Prev := Tokens[N-1]^.Key; Adjacent := True;
      for P := Tokens[N-1]^.Last to Tokens[N]^.First-1 do
        if Line[P] <> ' ' then Adjacent := False
    end;
    Correction := '';
    if W='sa' then begin
      if (N<TokenCount) then
        if InList(Tokens[N+1]^.Key,'va marche fonctionne suffit') then Correction := 'ça'
    end;
    if Adjacent then begin
      if (Prev='je') and (W='suis') then begin end
      else if (Prev='je') and (W='suit') then Correction := 'suis'
      else if (Prev='tu') and InList(W,'est ai a') then Correction := 'es'
      else if InList(Prev,'il elle on') and InList(W,'es et') then Correction := 'est'
      else if (Prev='ils') and InList(W,'son est') then Correction := 'sont'
      else if (Prev='elles') and InList(W,'son est') then Correction := 'sont'
      else if (Prev='nous') and InList(W,'sont somme') then Correction := 'sommes'
      else if (Prev='vous') and InList(W,'est etes') and (Tokens[N]^.Raw<>'êtes') then Correction := 'êtes'
      else if (Prev='je') and InList(W,'manges parles aimes') then Correction := Copy(W,1,Length(W)-1)
      else if (Prev='tu') and InList(W,'mange parle aime') then Correction := W+'s'
      else if InList(Prev,'il elle on') and InList(W,'manges parles aimes') then Correction := Copy(W,1,Length(W)-1)
      else if InList(Prev,'ils elles') and InList(W,'mange parle aime') then Correction := W+'nt';
      if (W=Prev) and not InList(W,'nous vous') then
        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'REPETITION','Mot repete.', '');
      if InList(Prev,'les des ces mes tes ses nos vos leurs') and
         InList(W,'chat chien maison voiture livre enfant fille garcon ami pomme') then
        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'ACCORD_NOMBRE','Un pluriel est attendu apres ce determinant.',W+'s');
      if InList(Prev,'la une cette ma ta sa') and InList(W,'chat chien garcon livre') then
        AddError(Tokens[N-1]^.First,Tokens[N-1]^.Last,False,'ACCORD_GENRE','Verifier le genre du determinant.','');
      if (W='a') and InList(Prev,'vais vas va allons allez vont aller') then
        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'A_ACCENT','La preposition prend un accent grave.','à');
      if (N>2) and InList(Tokens[N-2]^.Key,'les des ces mes tes ses nos vos leurs') and
         InList(Prev,'chats chiens enfants filles garcons amis voitures maisons') and
         InList(W,'mange parle aime') then
        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'ACCORD_VERBE',
          'Un verbe au pluriel est attendu avec ce sujet.',W+'nt');
      if InList(Prev,'maison voiture fille pomme') and
         InList(W,'petit grand joli vert bleu noir') then
        AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'ACCORD_ADJECTIF',
          'Verifier le feminin de cet adjectif.',W+'e')
    end;
    if Correction <> '' then
      AddError(Tokens[N]^.First,Tokens[N]^.Last,False,'CONFUSION','Verifier la conjugaison ou cet homophone.',Correction)
  end;
  for P := 1 to LineLen do begin
    if (Line[P] in [',','.']) and (P>1) then
      if Line[P-1]=' ' then AddError(P-1,P,False,'ESPACE_AVANT','Espace superflue avant la ponctuation.','');
    if (Line[P] in [',',';',':','!','?']) and (P<LineLen) then
      if Line[P+1] in ['a'..'z','A'..'Z'] then
        AddError(P+1,P+1,False,'ESPACE_APRES','Espace attendue apres la ponctuation.',' ')
  end
end;

procedure Spelling;
var N: Word; W, S: TWord;
begin
  for N := 1 to TokenCount do begin
    W := Tokens[N]^.Key; S := '';
    if W='bonjours' then S := 'bonjour'
    else if W='beaucoups' then S := 'beaucoup'
    else if W='malgres' then S := 'malgré'
    else if W='parmis' then S := 'parmi'
    else if W='biensur' then S := 'bien sûr'
    else if Tokens[N]^.Raw='francais' then S := 'français'
    else if Tokens[N]^.Raw='ecole' then S := 'école'
    else if Tokens[N]^.Raw='tres' then S := 'très'
    else if Tokens[N]^.Raw='etre' then S := 'être'
    else if Tokens[N]^.Raw='deja' then S := 'déjà'
    else if Tokens[N]^.Raw='apres' then S := 'après'
    else if Tokens[N]^.Raw='bientot' then S := 'bientôt';
    if S<>'' then
      AddError(Tokens[N]^.First,Tokens[N]^.Last,True,'ORTHOGRAPHE',
        'Orthographe a verifier.',S)
    else if not Known(W) then begin
      S := Suggest(W);
      AddError(Tokens[N]^.First,Tokens[N]^.Last,True,'ORTHOGRAPHE',
        'Mot absent du lexique embarque (nom propre ou mot rare possible).',S)
    end
  end
end;

procedure JString(S: string);
var N: Integer; C: Byte;
const Hex: string[16] = '0123456789abcdef';
begin
  Write(Report,'"');
  for N := 1 to Length(S) do begin
    C := Ord(S[N]);
    case C of
      34: Write(Report,'\"');
      92: Write(Report,'\\');
      0..31: Write(Report,'\u00',Hex[C div 16+1],Hex[C mod 16+1]);
    else Write(Report,S[N])
    end
  end;
  Write(Report,'"')
end;

procedure EmitErrors(Spell: Boolean);
var N: Word; First: Boolean;
begin
  First := True; Write(Report,'[');
  for N := 1 to ErrorCount do if Errors[N]^.Spelling=Spell then begin
    if not First then Write(Report,','); First := False;
    with Errors[N]^ do begin
      Write(Report,'{"nStart":',Errors[N]^.First,',"nEnd":',Last,',"sRuleId":');
      JString(Rule); Write(Report,',"sMessage":'); JString(MessageText);
      Write(Report,',"aSuggestions":[');
      if Suggestion<>'' then JString(Suggestion);
      Write(Report,']}')
    end
  end;
  Write(Report,']')
end;

procedure EmitLine;
var N: Word;
begin
  if OnlyErrors and (ErrorCount=0) then Exit;
  if Json then begin
    if not FirstParagraph then WriteLn(Report,','); FirstParagraph := False;
    Write(Report,'{"iParagraph":',Paragraph,',"lGrammarErrors":');
    EmitErrors(False); Write(Report,',"lSpellingErrors":'); EmitErrors(True);
    Write(Report,'}')
  end else begin
    Write(Report,Paragraph,': ');
    for N := 1 to LineLen do Write(Report,Line[N]);
    WriteLn(Report);
    for N := 1 to ErrorCount do with Errors[N]^ do begin
      Write(Report,'  ',First+1,'-',Last,' [',Rule,'] ',MessageText);
      if Suggestion<>'' then Write(Report,' Suggestion: ',Suggestion);
      WriteLn(Report)
    end
  end
end;

procedure Help;
begin
  WriteLn('GRAMMALECTE-CLI - Cette commande permet de lancer le correcteur francais autonome (lexique limite).');
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
end;

function ResultName(S: string): string;
var N, DotAt: Integer;
begin
  DotAt := 0;
  for N := Length(S) downto 1 do begin
    if S[N] in ['\','/',':'] then Break;
    if S[N]='.' then begin DotAt := N; Break end
  end;
  if DotAt>0 then Delete(S,DotAt,Length(S)-DotAt+1);
  if Length(S)>244 then Fail('nom du rapport trop long');
  if Json then ResultName := S+'.res.json' else ResultName := S+'.res.txt'
end;

function UpperName(S: string): string;
var N: Integer;
begin
  for N := 1 to Length(S) do S[N] := UpCase(S[N]);
  UpperName := S
end;

procedure ReadLine;
var C: Char; N, Need, B: Word; V, LowBound, HighBound: Byte;
begin
  LineLen := 0;
  while not Eof(Source) do begin
    Read(Source,C);
    if C=#10 then Break;
    if C<>#13 then begin
      if LineLen=MaxLine then Fail('ligne de plus de 16000 octets');
      Inc(LineLen); Line[LineLen] := C
    end
  end;
  if (Paragraph=1) and (LineLen>=3) then
    if (Ord(Line[1])=$EF) and (Ord(Line[2])=$BB) and (Ord(Line[3])=$BF) then begin
      for N := 4 to LineLen do Line[N-3] := Line[N]; Dec(LineLen,3)
    end;
  N := 1;
  while N<=LineLen do begin
    V := Ord(Line[N]); Need := 0; LowBound := $80; HighBound := $BF;
    if V<$80 then begin
      if (V<32) and (V<>9) then Fail('caractere de controle dans le fichier')
    end
    else if V in [$C2..$DF] then Need := 1
    else if V in [$E0..$EF] then begin
      Need := 2; if V=$E0 then LowBound := $A0;
      if V=$ED then HighBound := $9F
    end
    else if V in [$F0..$F4] then begin
      Need := 3; if V=$F0 then LowBound := $90;
      if V=$F4 then HighBound := $8F
    end else Fail('encodage UTF-8 invalide');
    if N+Need>LineLen then Fail('sequence UTF-8 incomplete');
    for B := 1 to Need do begin
      V := Ord(Line[N+B]);
      if (V<LowBound) or (V>HighBound) then Fail('encodage UTF-8 invalide');
      LowBound := $80; HighBound := $BF
    end;
    Inc(N,Need+1)
  end
end;

begin
  FileName := ''; ToFile := False; Json := False; OnlyErrors := False;
  I := 1;
  if ParamCount=0 then begin Help; Halt(0) end;
  while I<=ParamCount do begin
    Arg := ParamStr(I);
    if (Arg='-h') or (Arg='-?') or (Arg='--help') then begin Help; Halt(0) end
    else if Arg='--version' then begin WriteLn('GRAMMALECTE-CLI Pascal 1.0 (independant)'); Halt(0) end
    else if (Arg='-j') or (Arg='--json') then Json := True
    else if (Arg='-owe') or (Arg='--only_when_errors') then OnlyErrors := True
    else if (Arg='-f') or (Arg='--file') or (Arg='-ff') or (Arg='--file_to_file') then begin
      if FileName<>'' then Fail('un seul fichier est autorise');
      ToFile := (Arg='-ff') or (Arg='--file_to_file');
      Inc(I); if I>ParamCount then Fail('nom de fichier manquant');
      FileName := ParamStr(I)
    end else Fail('option inconnue: '+Arg);
    Inc(I)
  end;
  if FileName='' then Fail('utiliser -f ou -ff suivi du fichier');
  Assign(Source,FileName); {$I-} Reset(Source); {$I+}
  if IOResult<>0 then Fail('impossible de lire '+FileName);
  if ToFile then begin
    OutName := ResultName(FileName);
    if UpperName(OutName)=UpperName(FileName) then Fail('le rapport remplacerait le fichier source');
    Assign(Report,OutName)
  end else Assign(Report,'');
  {$I-} Rewrite(Report); {$I+}
  if IOResult<>0 then Fail('impossible de creer le rapport');
  for I := 1 to MaxTokens do New(Tokens[I]);
  for I := 1 to MaxErrors do New(Errors[I]);
  InitDictionary;
  Paragraph := 0; TotalGrammar := 0; TotalSpelling := 0; FirstParagraph := True;
  if Json then WriteLn(Report,'{"sVersion":"pascal-1.0","sLangCode":"fr","sScope":"limited-embedded-lexicon","data":[');
  while not Eof(Source) do begin
    Inc(Paragraph); ReadLine; Tokenize; ErrorCount := 0;
    Grammar; Spelling; EmitLine
  end;
  if Json then WriteLn(Report,'],"nGrammarErrors":',TotalGrammar,',"nSpellingErrors":',TotalSpelling,'}')
  else WriteLn(Report,TotalGrammar,' erreur(s) grammaticale(s), ',TotalSpelling,' mot(s) inconnu(s).');
  Close(Source);
  {$I-} Close(Report); {$I+} IOCode := IOResult;
  if IOCode<>0 then Halt(2)
end.
