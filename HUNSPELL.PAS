{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/correcteur-0)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
 @description: Correcteur orthographique autonome de francais et d'anglais. }

Program HUNSPELL;

{$IFDEF FPC}
 {$MODE TP}{$H-}
{$ENDIF}
{$R+}

Uses Dos;

Const
 MaxWords = 2400;
 MaxSuggestions = 5;

Type
 TWord = String[80];
 PWord = ^TWord;
 TUnit = String[4];

Var
 Dictionary: Array[1..MaxWords] Of PWord;
 WordCount: Integer;
 Suggestions: Array[1..MaxSuggestions] Of TWord;
 Scores: Array[1..MaxSuggestions] Of Integer;
 SuggestionCount: Integer;
 Source: File;
 Buffer: Array[1..4096] Of Byte;
 BufferPos, BufferCount: Word;
 FileName, DictName, Arg: String;
 ListOnly, ReplaceWords, LastCR: Boolean;
 LineNumber, ColumnNumber, WordLine, WordColumn: LongInt;
 CurrentWord: TWord;
 UnitText: TUnit;
 I: Integer;
{ Source ASCII only. Numeric strings contain UTF-8 bytes, not DOS codes.
  Built-in French and English vocabularies; no external files needed.
  Independent subset, not the Hunspell engine. No affix/compound engine.
  -U emits corrected UTF-8 on stdout; input bytes are never overwritten.
  Unknown words without a suggestion remain unchanged. Exit 0/2. }

Procedure Fail(S: String);Begin
 {$IFDEF FPC}
  WriteLn(StdErr,'Erreur: ',S);
 {$ELSE}
  WriteLn('Erreur: ',S);
 {$ENDIF}
 Halt(2)
End;

Function Lower(S: TWord): TWord;
Var
 P, B: Integer;
Begin
 P := 1;
 While P <= Length(S) Do Begin
  B := Ord(S[P]);
  If B In [65..90] Then S[P] := Chr(B+32);
  If (B=195) And (P<Length(S)) Then Begin
   Inc(P); B := Ord(S[P]);
   If (B In [128..150,152..158]) Then S[P] := Chr(B+32)
  End Else If (B=197) And (P<Length(S)) Then Begin
   Inc(P); If Ord(S[P])=146 Then S[P] := #147
  End;
  Inc(P)
 End;
 Lower := S
End;
{ Shared vocabulary is copied into this source, never included at compile
  time. Exact spelling retains accents; Fold is only used for ranking. }

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

Procedure FrenchWords;
Begin
 Words(
 'a '#195#160' ai aie aies ait as au aux avec avant apr'#195#168's assez aussi autant autre');
 Words('autres aucun aucune');
 Words('alors ainsi aller allons allez allez-vous');
 Words(
 'avoir avons avez avaient avais avait ayant eu eue eus eues aurai auras aura aurons aurez');
 Words('auront');
 Words('aurais aurait auraient');
 Words(#195#170'tre suis es est sommes '#195#170'tes sont '#195#169'tais '#195#169'tait');
 Words(#195#169'tions '#195#169'tiez '#195#169'taient '#195#169't'#195#169' serai seras');
 Words('sera serons serez seront serait seraient sois soit soient');
 Words(
 'bonjour bonsoir salut merci oui non peut-'#195#170'tre voici voil'#195#160' bien mal mieux');
 Words('tr'#195#168's trop peu plus');
 Words('moins beaucoup tout tous toute toutes');
 Words(
 'ce cet cette ces celui celle ceux celles ceci cela '#195#167'a de du des le la les un une et');
 Words('ou o'#195#185);
 Words('mais donc or ni car si sinon');
 Words(
 'je tu il elle on nous vous ils elles me te se moi toi soi lui leur leurs mon ma mes ton ta');
 Words('tes');
 Words('son sa ses notre nos votre vos');
 Words(
 'dans sur sous par pour sans entre vers chez contre depuis pendant durant malgr'#195#169)
 ;
 Words('selon parmi');
 Words('devant derri'#195#168're');
 Words(
 'ne pas jamais rien personne aucun seulement encore d'#195#169'j'#195#160' toujours souvent');
 Words('parfois quelquefois');
 Words('maintenant aujourd'#226#128#153'hui demain hier');
 Words(
 'ici l'#195#160' ailleurs partout ensemble quand comme comment pourquoi parce que qui quoi');
 Words('dont lequel');
 Words('laquelle lesquels lesquelles');
 Words(
 'chaque plusieurs quelques quelque m'#195#170'me m'#195#170'mes certain certains certaine');
 Words('certaines tel telle');
 Words('tels telles');
 Words(
 'puis peux peut pouvons pouvez peuvent pouvais pouvait pouvaient pu dois doit devons devez');
 Words('doivent devrait devraient d'#195#187);
 Words(
 'fais fait faisons faites font faisais faisait faisaient faire faisant vais vas va vont aller');
 Words('viens vient venons venez viennent venir');
 Words(
 'veux veut voulons voulez veulent vouloir sais sait savons savez savent savoir vois voit');
 Words('voyons');
 Words('voyez voient voir');
 Words(
 'dis dit disent dire donne donnes donnent donner prends prend prendre pense penses pensent');
 Words('penser aime aimes aiment aimer');
 Words(
 'parle parles parlent parlons parlez parler mange manges mangent mangeons mangez manger')
 ;
 Words('travaille travaillent travailler');
 Words(
 'habite habitent habiter regarde regardent regarder trouve trouvent trouver semble semblent');
 Words('sembler reste restent rester');
 Words(
 'faut fallait fallait falloir pleut pleuvoir existe existent existez '#195#169'crit');
 Words(#195#169'cris '#195#169'crivent');
 Words(#195#169'crire lire lis lit lisent lu lue');
 Words(
 'bonjour monde texte textes fichier fichiers phrase phrases mot mots mot-cl'#195#169' exemple');
 Words('exemples');
 Words('erreur erreurs faute fautes');
 Words(
 'fran'#195#167'ais fran'#195#167'aise fran'#195#167'aises langue langues grammaire orthographe');
 Words('correction correcteur');
 Words('correcteurs dictionnaire rapport r'#195#169'sultat r'#195#169'sultats');
 Words(
 'petit petits petite petites grand grands grande grandes bon bons bonne bonnes mauvais');
 Words('mauvaise');
 Words('mauvaises beau beaux belle belles');
 Words(
 'nouveau nouveaux nouvelle nouvelles vieux vieille vieilles jeune jeunes joli jolis jolie');
 Words('jolies');
 Words('heureux heureuse heureuses');
 Words(
 'chat chats chatte chattes chien chiens chienne chiennes animal animaux cheval chevaux oiseau');
 Words('oiseaux poisson poissons');
 Words(
 'maison maisons jardin jardins voiture voitures livre livres '#195#169'cole '#195#169'coles');
 Words('classe classes');
 Words(#195#169'l'#195#168've '#195#169'l'#195#168'ves enfant enfants');
 Words(
 'homme hommes femme femmes fille filles gar'#195#167'on gar'#195#167'ons ami amis amie amies');
 Words('famille familles');
 Words('p'#195#168're m'#195#168're fr'#195#168're soeur s'#197#147'ur');
 Words(
 'jour jours nuit nuits matin matins soir soirs semaine semaines mois ann'#195#169'e');
 Words('ann'#195#169'es an ans heure');
 Words('heures minute minutes temps');
 Words(
 'eau pain vin lait caf'#195#169' th'#195#169' pomme pommes fruit fruits repas table tables');
 Words('chaise chaises porte');
 Words('portes fen'#195#170'tre fen'#195#170'tres');
 Words('ville villes pays rue rues route routes chemin chemins train trains avion avions')
 ;
 Words('v'#195#169'lo bateau');
 Words('bateaux travail travaux bureau bureaux');
 Words(
 'ordinateur ordinateurs programme programmes information informations syst'#195#168'me');
 Words('syst'#195#168'mes');
 Words('donn'#195#169'es document documents ligne lignes');
 Words(
 'important importants importante importantes possible possibles impossible impossibles simple');
 Words('simples difficile difficiles facile faciles');
 Words('vrai vrais vraie vraies faux fausse fausses premier premiers premi'#195#168're');
 Words('premi'#195#168'res dernier');
 Words('derniers derni'#195#168're derni'#195#168'res');
 Words(
 'rouge rouges vert verts verte vertes bleu bleus bleue bleues blanc blancs blanche blanches');
 Words('noir');
 Words('noirs noire noires');
 Words(
 'gentil gentils gentille gentilles content contents contente contentes heureux heureuse triste');
 Words('tristes fatigu'#195#169' fatigu'#195#169's fatigu'#195#169'e fatigu'#195#169'es');
 Words(
 'deux trois quatre cinq six sept huit neuf dix onze douze cent cents mille million millions');
 Words('z'#195#169'ro');
 Words(
 'chose choses probl'#195#168'me probl'#195#168'mes question questions r'#195#169'ponse');
 Words('r'#195#169'ponses raison raisons besoin');
 Words('besoins point points cas mani'#195#168're fa'#195#167'on');
 Words('d'#195#169'but fin suite partie parties place places c'#195#180't'#195#169);
 Words('c'#195#180't'#195#169's droit droite gauche centre nord sud');
 Words('ouest');
 Words(
 'vraiment simplement rapidement lentement facilement correctement notamment '#195#169'galement');
 Words('cependant');
 Words('pourtant ensuite enfin plut'#195#180't presque');
 Words(
 'attention accord accords nom noms verbe verbes sujet sujets adjectif adjectifs pluriel')
 ;
 Words('singulier f'#195#169'minin masculin');
 Words(
 'merci monsieur madame bon bonne journ'#195#169'e bienvenue bient'#195#180't revoir plaisir');
 Words('sant'#195#169' vie mort');
 Words('amour paix');
 Words(
 'pris prise compris comprendre appris apprendre ouvert ouvrir ferm'#195#169' fermer');
 Words('re'#195#167'u recevoir');
 Words('envoy'#195#169' envoyer utilis'#195#169' utiliser');
 Words(
 'besoin envie peur raison tort cours course histoire histoires musique film films photo photos');
 Words('image images');
 Words('l d j c n s t m qu jusqu lorsqu puisqu aujourd hui est-ce');
End;

Procedure EnglishWords;
Begin
 Words('a an the this that these those i you he she it we they me him her us them');
 Words('my your his its our their mine yours hers ours theirs myself yourself himself');
 Words('herself itself ourselves yourselves themselves who whom whose which what');
 Words('am is are was were be been being have has had having do does did done doing');
 Words('will would shall should can could may might must ought need dare not no yes');
 Words('and or but if then else because so although though while until unless since');
 Words('as than whether either neither both all any some each every much many few');
 Words('more most less least other another such same only own enough several none');
 Words('in on at to from by for with without of about above below over under between');
 Words('through across along around against among before after during into onto upon');
 Words('up down out off away back here there where when why how now very too also');
 Words('just still already yet always never ever often sometimes usually again once');
 Words('twice together apart almost quite rather really well even perhaps maybe');
 Words('hello hi goodbye welcome please thanks thank sorry excuse okay ok dear');
 Words('world word words text texts file files document documents line lines page pages');
 Words('spell spelling checker check checks checked checking correct correction corrections');
 Words('error errors mistake mistakes suggestion suggestions dictionary dictionaries');
 Words('english french language languages sentence sentences grammar letter letters');
 Words('write writes writing written wrote read reads reading reader readers book books');
 Words('say says said tell tells told speak speaks speaking spoken talk talks talking');
 Words('go goes going gone went come comes coming came get gets getting got');
 Words('make makes making made take takes taking taken took give gives giving given gave');
 Words('see sees seeing seen saw look looks looking looked watch watches watched');
 Words('know knows knowing known knew think thinks thinking thought understand understood');
 Words('want wants wanted like likes liked love loves loved hate hates hated');
 Words('work works working worked use uses using used try tries trying tried');
 Words('help helps helping helped find finds finding found keep keeps kept');
 Words('learn learns learned learning teach teaches teaching taught study studies');
 Words('play plays playing played run runs running ran walk walks walked walking');
 Words('eat eats eating eaten ate drink drinks drinking drunk drank sleep sleeps slept');
 Words('live lives lived living move moves moved moving leave leaves leaving left');
 Words('put puts putting let lets letting set sets setting sit sits sitting sat');
 Words('stand stands standing stood open opens opened close closes closed');
 Words('start starts started starting stop stops stopped stopping finish finished');
 Words('change changes changed changing turn turns turned turning bring brings brought');
 Words('buy buys buying bought sell sells selling sold pay pays paying paid');
 Words('send sends sending sent receive receives received receiving believe believes');
 Words('believed believing achieve achieved achieving become becomes became become');
 Words('happen happens happened happening occur occurs occurred occurring');
 Words('remember remembers remembered forget forgets forgot forgotten');
 Words('worry worries worried worrying hope hopes hoped hoping wish wishes wished');
 Words('feel feels feeling felt hear hears hearing heard meet meets meeting met');
 Words('good better best bad worse worst new old young great small big large little');
 Words('long short tall high low wide narrow early late first last next previous');
 Words('happy sad easy difficult simple hard possible impossible true false right wrong');
 Words('beautiful nice pretty ugly important different interesting useful careful');
 Words('quick fast slow quiet loud clear clean dirty full empty hot cold warm cool');
 Words('red green blue yellow black white brown orange purple pink grey gray');
 Words('one two three four five six seven eight nine ten eleven twelve hundred thousand');
 Words('zero million number numbers time times day days night nights morning evening');
 Words('today yesterday tomorrow week weeks month months year years hour hours minute');
 Words('minutes second seconds monday tuesday wednesday thursday friday saturday sunday');
 Words('january february march april may june july august september october november december');
 Words('man men woman women child children boy boys girl girls baby babies person people');
 Words('friend friends family families father mother brother sister son daughter parent parents');
 Words('name names home homes house houses room rooms door doors window windows');
 Words('table tables chair chairs bed beds kitchen garden school schools class classes');
 Words('student students teacher teachers lesson lessons office business company companies');
 Words('job jobs money price prices shop shops store stores market markets');
 Words('city cities town towns country countries street streets road roads car cars');
 Words('bus buses train trains plane planes boat boats bike bikes bicycle bicycles');
 Words('water food bread milk tea coffee apple apples fruit fruits vegetable vegetables');
 Words('meat fish egg eggs rice potato potatoes tomato tomatoes cheese sugar salt');
 Words('cat cats dog dogs horse horses bird birds animal animals tree trees flower flowers');
 Words('sun moon star stars sky rain snow wind weather sea river mountain mountains');
 Words('computer computers program programs software hardware system systems data');
 Words('information message messages email emails internet network networks website websites');
 Words('screen screens keyboard mouse button buttons folder folders command commands');
 Words('option options parameter parameters code source output input result results');
 Words('report reports test tests testing version versions update updates updated');
 Words('question questions answer answers problem problems solution solutions example examples');
 Words('idea ideas reason reasons fact facts way ways thing things part parts place places');
 Words('story stories history music song songs film films movie movies picture pictures');
 Words('image images photo photos game games team teams life health peace love');
 Words('public private free available special general common local national international');
 Words('quickly slowly carefully correctly especially probably actually certainly');
 Words('really simply usually finally recently suddenly immediately unfortunately');
 Words('beautifully definitely necessary separate receive address addresses tomorrow');
 Words('beginning accommodation environment government successful success business');
 Words('don doesn didn couldn wouldn shouldn isn aren wasn weren hasn haven hadn');
 Words('mustn needn won shan t s m d re ve ll ain');
 If DictName='en_GB' Then Begin
  Words('colour colours coloured colouring favourite favourites neighbour neighbours');
  Words('centre centres theatre theatres metre metres litre litres honour honours');
  Words('behaviour organise organises organised organising organisation organisations');
  Words('recognise recognised realise realised travelling travelled traveller travellers');
  Words('programme programmes defence licence licences practise practised learnt got')
 End Else Begin
  Words('color colors colored coloring favorite favorites neighbor neighbors');
  Words('center centers theater theaters meter meters liter liters honor honors');
  Words('behavior organize organizes organized organizing organization organizations');
  Words('recognize recognized realize realized traveling traveled traveler travelers');
  Words('defense license licenses practice practiced learned gotten')
 End
End;

Procedure InitDictionary;
Var A,B: Integer; W: TWord;
Begin
 WordCount := 0;
 If DictName='fr_FR' Then FrenchWords Else EnglishWords;
  { Sort once; binary lookup preserves accented dictionary spellings. }
 For A := 2 To WordCount Do Begin
  W := Dictionary[A]^; B := A-1;
  While B > 0 Do Begin
   If Lower(Dictionary[B]^) <= Lower(W) Then Break;
   Dictionary[B+1]^ := Dictionary[B]^; Dec(B)
  End;
  Dictionary[B+1]^ := W
 End
End;

Function Known(W: TWord): Boolean;
Var
 L,H,M: Integer;
 K: TWord;
Begin
 W := Lower(W); L := 1; H := WordCount; Known := False;
 While L<=H Do Begin
  M := (L+H) Div 2; K := Lower(Dictionary[M]^);
  If W=K Then Begin
   Known := True; Exit
  End;
  If W<K Then H := M-1 Else L := M+1
 End
End;

Function Distance(A,B: TWord): Integer;
Var
 Matrix: Array[0..80,0..80] Of Byte;
 X,Y,V: Integer;
Begin
 For X := 0 To Length(A) Do Matrix[X,0] := X;
 For Y := 0 To Length(B) Do Matrix[0,Y] := Y;
 For X := 1 To Length(A) Do
 For Y := 1 To Length(B) Do Begin
  V := Matrix[X-1,Y-1]; If A[X]<>B[Y] Then Inc(V);
  If Matrix[X-1,Y]+1<V Then V := Matrix[X-1,Y]+1;
  If Matrix[X,Y-1]+1<V Then V := Matrix[X,Y-1]+1;
  If (X>1) And (Y>1) Then    If (A[X]=B[Y-1]) And (A[X-1]=B[Y]) Then     If Matrix[X-2,Y-
  2]+1<V Then V := Matrix[X-2,Y-2]+1;
  Matrix[X,Y] := V
 End;
 Distance := Matrix[Length(A),Length(B)]
End;

Function MatchCase(S,Original: TWord): TWord;
Var
 P,B: Integer;
 AllUpper, FirstUpper: Boolean;
Begin
 AllUpper := True; FirstUpper := False; P := 1;
 While P<=Length(Original) Do Begin
  B := Ord(Original[P]);
  If B In [97..122] Then AllUpper := False;
  If (P=1) And (B In [65..90]) Then FirstUpper := True;
  If (B=195) And (P<Length(Original)) Then Begin
   Inc(P); B := Ord(Original[P]);
   If B In [160..182,184..190] Then AllUpper := False;
   If (P=2) And (B In [128..150,152..158]) Then FirstUpper := True
  End;
  Inc(P)
 End;
 P := 1;
 While P<=Length(S) Do Begin
  B := Ord(S[P]);
  If AllUpper Or (FirstUpper And (P=1)) Then Begin
   If B In [97..122] Then S[P] := Chr(B-32);
   If (B=195) And (P<Length(S)) Then Begin
    Inc(P); B := Ord(S[P]);
    If B In [160..182,184..190] Then S[P] := Chr(B-32)
   End
  End;
  Inc(P)
 End;
 MatchCase := S
End;

Procedure InsertSuggestion(W: TWord; Score: Integer);
Var
 P,N,Limit: Integer;
Begin
 For N := 1 To SuggestionCount Do If Suggestions[N]=W Then Exit;
 P := 1;
 While P<=SuggestionCount Do Begin
  If Score<Scores[P] Then Break;
  Inc(P)
 End;
 If P>MaxSuggestions Then Exit;
 Limit := SuggestionCount;
 If Limit<MaxSuggestions Then Inc(SuggestionCount) Else Dec(Limit);
 For N := Limit Downto P Do Begin
  Suggestions[N+1] := Suggestions[N]; Scores[N+1] := Scores[N]
 End;
 Suggestions[P] := W; Scores[P] := Score
End;

Procedure Suggest(W: TWord);
Var
 N,D,Limit: Integer;
 K,F,Preferred: TWord;
Begin
 SuggestionCount := 0; W := Lower(W); F := Fold(W);
 Preferred := '';
 If DictName='fr_FR' Then Begin
 If W='bonjours' Then Preferred := 'bonjour';
 If W='beaucoups' Then Preferred := 'beaucoup';
 If W='malgres' Then Preferred := 'malgr'#195#169;
 If W='parmis' Then Preferred := 'parmi';
 If W='biensur' Then Preferred := 'bien s'#195#187'r';
 End Else Begin
  If W='teh' Then Preferred := 'the';
  If W='helo' Then Preferred := 'hello';
  If W='wrld' Then Preferred := 'world';
  If W='recieve' Then Preferred := 'receive';
  If W='becuase' Then Preferred := 'because';
  If W='seperate' Then Preferred := 'separate';
  If W='definately' Then Preferred := 'definitely';
  If W='adress' Then Preferred := 'address';
  If W='tomorow' Then Preferred := 'tomorrow';
  If W='langauge' Then Preferred := 'language';
  If W='beutiful' Then Preferred := 'beautiful'
 End;
 If Preferred<>'' Then InsertSuggestion(Preferred,0);
 Limit := 2; If Length(F)<5 Then Limit := 1;
 For N := 1 To WordCount Do Begin
  K := Fold(Dictionary[N]^);
  If Abs(Length(F)-Length(K))<=Limit Then Begin
   D := Distance(F,K);
   If D<=Limit Then Begin
    { Exact accent/case-insensitive matches rank before edit corrections. }
    If D=0 Then InsertSuggestion(Dictionary[N]^,1)
           Else InsertSuggestion(Dictionary[N]^,D*10+2)
   End
  End
 End
End;

Function ReadByte(Var B: Byte): Boolean;Begin
 If BufferPos>BufferCount Then Begin
  {$I-} BlockRead(Source,Buffer,SizeOf(Buffer),BufferCount); {$I+}
  If IOResult<>0 Then Fail('lecture du fichier impossible');
  BufferPos := 1
 End;
 ReadByte := BufferCount<>0;
 If BufferCount<>0 Then Begin
  B := Buffer[BufferPos]; Inc(BufferPos)
 End
End;

Function ReadUnit(Var S: TUnit): Boolean;
Var
 B,Lead,LowBound,HighBound: Byte;
 N,Need: Integer;
Begin
 S := ''; ReadUnit := False;
 If Not ReadByte(Lead) Then Exit;
 S := Chr(Lead); Need := 0; LowBound := $80; HighBound := $BF;
 If Lead<$80 Then Begin
  If (Lead<32) And Not (Lead In [9,10,13]) Then Fail('caractere de controle interdit')
 End Else If Lead In [$C2..$DF] Then Need := 1 Else
 If Lead In [$E0..$EF] Then Begin
  Need := 2;
  If Lead=$E0 Then LowBound := $A0;
  If Lead=$ED Then HighBound := $9F
 End Else If Lead In [$F0..$F4] Then Begin
  Need := 3;
  If Lead=$F0 Then LowBound := $90;
  If Lead=$F4 Then HighBound := $8F
 End Else Fail('encodage UTF-8 invalide');
 For N := 1 To Need Do Begin
  If Not ReadByte(B) Then Fail('sequence UTF-8 incomplete');
  If (B<LowBound) Or (B>HighBound) Then Fail('encodage UTF-8 invalide');
  S := S+Chr(B); LowBound := $80; HighBound := $BF
 End;
 ReadUnit := True
End;

Function IsLetter(S: TUnit): Boolean;
Var
 B: Byte;
Begin
 B := Ord(S[1]);
 IsLetter := (B In [65..90,97..122]);
 If Length(S)=2 Then Begin
  If B In [$C3..$CA] Then IsLetter := True;
  If (B=$C3) And (Ord(S[2]) In [$97,$B7]) Then IsLetter := False
 End
End;

Procedure Emit(S: String);Begin
 {$I-} Write(S); {$I+}
 If IOResult<>0 Then Fail('ecriture de la sortie impossible')
End;

Procedure CheckWord;
Var
 N: Integer;
 S: TWord;
Begin
 If CurrentWord='' Then Exit;
 If Known(CurrentWord) Then Begin
  If ReplaceWords Then Emit(CurrentWord)
 End Else
 Begin
  If ListOnly Then Begin
   Emit(CurrentWord); WriteLn
  End
   Else
  Begin
   Suggest(CurrentWord);
   If ReplaceWords Then Begin
    S := CurrentWord;
    If SuggestionCount>0 Then S := MatchCase(Suggestions[1],CurrentWord);
    Emit(S)
   End Else
   Begin
    Write(WordLine,':',WordColumn,' ',CurrentWord,' -> ');
    If SuggestionCount=0 Then Write('(aucune suggestion)');
    For N := 1 To SuggestionCount Do Begin
     If N>1 Then Write(', ');
     Emit(MatchCase(Suggestions[N],CurrentWord))
    End;
    WriteLn
   End
  End
 End;
 CurrentWord := ''
End;

Procedure Help;Begin
 WriteLn('HUNSPELL 1.1 - Cette commande permet de lancer le correcteur autonome de francais et d''anglais.');
 WriteLn;
 WriteLn('Syntaxe: hunspell [-d fr_FR|en_US|en_GB] [-l | -U] document.txt');
 WriteLn;
 WriteLn('  -d fr_FR      Lexique francais embarque (valeur par defaut)');
 WriteLn('  -d en_US      Lexique anglais americain embarque');
 WriteLn('  -d en_GB      Lexique anglais britannique embarque');
 WriteLn('  -l            Afficher seulement les mots suspects');
 WriteLn('  -U            Afficher le texte corrige par la premiere suggestion');
 WriteLn('  -h, --help    Aide');
 WriteLn('  -v, --version Version');
 WriteLn('  -D            Liste des lexiques');
 WriteLn;
 WriteLn('Sans -l ni -U: diagnostics ligne:colonne et suggestions.');
 WriteLn('Le fichier reste intact. Entrees/sorties UTF-8. Mot: 80 octets max.');
 WriteLn('Lexique reduit, sans moteur .aff/.dic ni interface interactive.')
End;

BEGIN
 FileName := ''; DictName := 'fr_FR'; ListOnly := False; ReplaceWords := False;
 I := 1;
 While I<=ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg='--help') Or (Arg='-h') Then Begin
   Help; Halt(0)
  End
  Else If (Arg='--version') Or (Arg='-v') Then Begin
   WriteLn('HUNSPELL Pascal 1.1 (implementation independante)'); Halt(0)
  End Else If Arg='-D' Then Begin
   WriteLn('fr_FR (francais, embarque, lexique reduit)');
   WriteLn('en_US (anglais americain, embarque, lexique reduit)');
   WriteLn('en_GB (anglais britannique, embarque, lexique reduit)'); Halt(0)
  End
  Else If Arg='-d' Then Begin
   Inc(I); If I>ParamCount Then Fail('dictionnaire manquant apres -d');
   DictName := ParamStr(I)
  End Else If Arg='-l' Then ListOnly := True Else
  If Arg='-U' Then ReplaceWords := True Else
  If (Arg<>'') And (Arg[1]='-') Then Fail('option inconnue: '+Arg)
   Else
  Begin
   If FileName<>'' Then Fail('un seul fichier est autorise');
   FileName := Arg
  End;
  Inc(I)
 End;
 If ParamCount=0 Then Begin
  Help; Halt(0)
 End;
 If (DictName<>'fr_FR') And (DictName<>'en_US') And (DictName<>'en_GB') Then
  Fail('lexique inconnu: utiliser fr_FR, en_US ou en_GB');
 If ListOnly And ReplaceWords Then Fail('-l et -U sont incompatibles');
 If FileName='' Then Fail('nom de fichier manquant');
 InitDictionary;
 Assign(Source,FileName); {$I-} Reset(Source,1); {$I+}
 If IOResult<>0 Then Fail('impossible de lire '+FileName);
 BufferPos := 1; BufferCount := 0;
 LineNumber := 1; ColumnNumber := 1; LastCR := False; CurrentWord := '';
 While ReadUnit(UnitText) Do Begin
  If IsLetter(UnitText) Then Begin
   If CurrentWord='' Then Begin
    WordLine := LineNumber; WordColumn := ColumnNumber
   End;
   If Length(CurrentWord)+Length(UnitText)>80 Then Fail('mot de plus de 80 octets');
   CurrentWord := CurrentWord+UnitText
  End Else
  Begin
   CheckWord;
   If ReplaceWords Then Emit(UnitText)
  End;
  If UnitText=#13 Then Begin
   Inc(LineNumber); ColumnNumber := 1; LastCR := True
  End
  Else If UnitText=#10 Then Begin
   If Not LastCR Then Inc(LineNumber);
   ColumnNumber := 1; LastCR := False
  End Else
  Begin
   If UnitText<>#239#187#191 Then Inc(ColumnNumber);
   LastCR := False
  End
 End;
 CheckWord;
 {$I-} Close(Source); {$I+}
 If IOResult<>0 Then Fail('fermeture du fichier impossible');
 {$I-} Flush(Output); {$I+}
 If IOResult<>0 Then Fail('ecriture de la sortie impossible')
END.
