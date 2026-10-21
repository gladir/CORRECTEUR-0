{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/correcteur-0)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
 @description: Correcteur autonome de francais, anglais, allemand, espagnol et italien. }

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
  Built-in French, English, German, Spanish and Italian; no external files needed.
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
  If Copy(S,P,3)=#225#186#158 Then Begin
   Delete(S,P,3); Insert(#195#159,S,P)
  End;
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

Procedure GermanWords;
Begin
 Words(#195#150'l');
 Words('ich du er sie es wir ihr mich dich ihn uns euch mir dir ihm ihnen');
 Words('mein meine meinen meinem meiner meines dein deine sein seine unser unsere euer eure');
 Words('der die das den dem des ein eine einen einem einer eines kein keine keinen keiner');
 Words('dieser diese dieses diesen diesem jeder jede jedes alle alles beide viele viel wenige');
 Words('etwas nichts man jemand niemand selbst bin bist ist sind seid war warst waren wart');
 Words('gewesen sein habe hast hat haben habt hatte hatten gehabt werde wirst wird werden');
 Words('wurde wurden worden und oder aber denn weil wenn als dass ob obwohl damit bevor');
 Words('nachdem bis seit w'#195#164'hrend sondern also doch nur auch noch schon sehr mehr weniger');
 Words('am an auf aus bei mit nach von zu zum zur f'#195#188'r '#195#188'ber unter vor hinter neben');
 Words('zwischen');
 Words('ohne gegen durch um im ins beim vom ja nein nicht bitte danke gern gerne heute morgen');
 Words('gestern jetzt hier dort da immer nie niemals oft manchmal bald wieder zusammen allein');
 Words('vielleicht wirklich leider einfach ziemlich besonders kann kannst k'#195#182'nnen');
 Words('k'#195#182'nnt konnte');
 Words('konnten darf darfst d'#195#188'rfen d'#195#188'rft muss musst m'#195#188'ssen m'#195#188'sst');
 Words('musste mussten soll sollst');
 Words('sollen sollt sollte sollten will willst wollen wollt wollte wollten m'#195#182'chte');
 Words('m'#195#182'chten');
 Words('gut gute guten guter gutes besser beste schlecht schlechte klein kleine kleinen');
 Words('gro'#195#159' gro'#195#159'e gro'#195#159'en sch'#195#182'n sch'#195#182'ne sch'#195#182'nen');
 Words('sch'#195#182'nes neu neue neuen alt alte alten jung junge');
 Words('lang lange kurz kurze hoch hohe niedrig richtig falsch wichtig m'#195#182'glich');
 Words('unm'#195#182'glich leicht');
 Words('schwer schnell langsam fr'#195#188'h sp'#195#164't warm kalt hei'#195#159' frei offen');
 Words('geschlossen m'#195#188'de gl'#195#188'cklich');
 Words('traurig freundlich klar sauber leer voll Hallo hallo Welt Tag Tage Nacht N'#195#164'chte');
 Words('Morgen');
 Words('Abend Woche Wochen Monat Monate Jahr Jahre Stunde Stunden Minute Minuten Zeit Zeiten');
 Words('Montag Dienstag Mittwoch Donnerstag Freitag Samstag Sonntag Januar Februar M'#195#164'rz April');
 Words('Mai Juni Juli August September Oktober November Dezember Mensch Menschen Mann M'#195#164'nner');
 Words('Frau Frauen Kind Kinder Junge Jungen M'#195#164'dchen Baby Familie Vater Mutter Eltern Bruder');
 Words('Schwester Sohn Tochter Freund Freunde Freundin Name Namen Haus H'#195#164'user Wohnung Zimmer');
 Words('T'#195#188'r T'#195#188'ren Fenster Tisch Stuhl Bett K'#195#188'che Garten Schule Schulen');
 Words('Lehrer Lehrerin Sch'#195#188'ler');
 Words('Sch'#195#188'lerin Klasse Universit'#195#164't Buch B'#195#188'cher Seite Seiten Brief Briefe');
 Words('Wort W'#195#182'rter Satz S'#195#164'tze');
 Words('Text Texte Sprache Sprachen Deutsch Englisch Franz'#195#182'sisch Grammatik Rechtschreibung');
 Words('Fehler Korrektur W'#195#182'rterbuch Vorschlag Vorschl'#195#164'ge Datei Dateien Zeile Zeilen');
 Words('Zeichen');
 Words('Dokument Dokumente Programm Programme Computer Rechner Tastatur Maus Bildschirm Internet');
 Words('Nachricht Nachrichten Daten System Ausgabe Eingabe Ergebnis Ergebnisse Befehl Befehle');
 Words('Option Optionen Test Tests Version Hilfe Frage Fragen Antwort Antworten Problem Probleme');
 Words('L'#195#182'sung L'#195#182'sungen Beispiel Beispiele Stadt St'#195#164'dte Land');
 Words('L'#195#164'nder Dorf D'#195#182'rfer Stra'#195#159'e Stra'#195#159'en');
 Words('Weg Wege Auto Autos Bus Zug Z'#195#188'ge Bahn Bahnhof Flugzeug Fahrrad Reise Reisen Arbeit');
 Words('Beruf');
 Words('B'#195#188'ro Geld Preis Gesch'#195#164'ft Laden Markt Wasser Brot Milch Kaffee Tee Apfel');
 Words(#195#132'pfel Obst Gem'#195#188'se');
 Words('Fleisch Fisch Ei Eier Reis Kartoffel Kartoffeln Tomate Tomaten K'#195#164'se Zucker Salz Essen');
 Words('Fr'#195#188'hst'#195#188'ck Mittagessen Abendessen Hund Hunde Katze Katzen Tier Tiere Pferd');
 Words('Vogel V'#195#182'gel');
 Words('Baum B'#195#164'ume Blume Blumen Sonne Mond Stern Sterne Himmel Regen Schnee Wind Wetter See');
 Words('Meer');
 Words('Fluss Berg Berge Wald Feuer Erde Luft Hand H'#195#164'nde Fu'#195#159' F'#195#188#195#159'e');
 Words('Kopf Auge Augen Ohr Ohren Herz');
 Words('Leben Gesundheit Frieden Liebe Musik Lied Lieder Film Filme Bild Bilder Spiel Spiele');
 Words('Sport Urlaub Deutschland Berlin M'#195#188'nchen '#195#150'sterreich Schweiz gehen geht gehe');
 Words('gehst ging');
 Words('gingen gegangen kommen kommt komme kommst kam kamen gekommen machen macht mache machst');
 Words('gemacht sagen sagt sage sagst sagte gesagt sehen sieht sehe siehst sah gesehen h'#195#182'ren');
 Words('h'#195#182'rt h'#195#182're geh'#195#182'rt lesen liest lese las gelesen schreiben schreibt');
 Words('schreibe geschrieben');
 Words('sprechen spricht spreche gesprochen lernen lernt lerne gelernt arbeiten arbeitet arbeite');
 Words('gearbeitet spielen spielt spiele gespielt wohnen wohnt wohne gewohnt leben lebt lebe gelebt');
 Words('lieben liebt liebe geliebt hei'#195#159'en hei'#195#159't hei'#195#159'e essen isst esse');
 Words('gegessen trinken trinkt');
 Words('trinke getrunken schlafen schl'#195#164'ft schlafe geschlafen fahren f'#195#164'hrt fahre');
 Words('gefahren laufen');
 Words('l'#195#164'uft laufe gelaufen geben gibt gebe gegeben nehmen nimmt nehme genommen finden');
 Words('findet');
 Words('finde gefunden wissen wei'#195#159' wusste gewusst denken denkt denke gedacht glauben glaubt');
 Words('glaube geglaubt verstehen versteht verstehe verstanden fragen fragt frage gefragt');
 Words('antworten antwortet helfen hilft helfe geholfen brauchen braucht brauche gebraucht suchen');
 Words('sucht suche gesucht kaufen kauft kaufe gekauft bezahlen bezahlt '#195#182'ffnen');
 Words(#195#182'ffnet ge'#195#182'ffnet');
 Words('schlie'#195#159'en schlie'#195#159't geschlossen beginnen beginnt begonnen bleiben bleibt');
 Words('geblieben bringen');
 Words('bringt gebracht stehen steht gestanden sitzen sitzt gesessen liegen liegt gelegen tragen');
 Words('tr'#195#164'gt getragen zeigen zeigt gezeigt benutzen benutzt korrigieren korrigiert');
 Words('pr'#195#188'fen pr'#195#188'ft');
 Words('gepr'#195#188'ft speichern speichert gespeichert '#195#164'ndern '#195#164'ndert');
 Words('ge'#195#164'ndert funktionieren funktioniert');
 Words('versuchen versucht freuen freut treffen trifft getroffen halten h'#195#164'lt gehalten');
 Words('vergessen');
 Words('vergisst bekommen bekommt erkl'#195#164'ren erkl'#195#164'rt bestellen bestellt');
 Words('w'#195#188'nschen w'#195#188'nscht gew'#195#188'nscht');
 Words('danken dankt gedankt begr'#195#188#195#159'en begr'#195#188#195#159't besuchen besucht reisen');
 Words('reist gereist rot gr'#195#188'n blau');
 Words('gelb schwarz wei'#195#159' braun grau rosa orange eins zwei drei vier f'#195#188'nf sechs');
 Words('sieben acht neun');
 Words('zehn elf zw'#195#182'lf hundert tausend null Million Millionen erste zweite dritte letzte');
 Words('n'#195#164'chste');
 Words('andere einigen einige deshalb deswegen trotzdem au'#195#159'erdem n'#195#164'mlich bisschen');
 Words('Gr'#195#188#195#159'e Gru'#195#159);
 Words('gr'#195#182#195#159'er gr'#195#182#195#159'te Spa'#195#159' au'#195#159'en s'#195#188#195#159);
 Words('Fu'#195#159'g'#195#164'nger Fu'#195#159'ball Stra'#195#159'enbahnen Haust'#195#188'r');
 Words('Sonnenlicht');
 Words('Krankenhaus Geburtstag Wochenende Weihnachten');
End;

Procedure SpanishWords;
Begin
 Words(#195#177'and'#195#186);
 Words('yo t'#195#186' '#195#169'l ella usted nosotros nosotras vosotros vosotras ellos ellas ustedes');
 Words('me te se nos os lo la los las le les mi mis tu tus su sus nuestro nuestra nuestros');
 Words('nuestras vuestro vuestra vuestros vuestras m'#195#173'o m'#195#173'a tuyo tuya suyo suya');
 Words('contigo conmigo');
 Words('el un una unos unas este esta estos estas ese esa esos esas aquel aquella aquellos');
 Words('aquellas esto eso aquello cada todo toda todos todas otro otra otros otras alguno alguna');
 Words('algunos algunas ninguno ninguna mucho mucha muchos muchas poco poca pocos pocas');
 Words('varios varias ambos ambas mismo misma mismos mismas alguien nadie algo nada quien');
 Words('quienes cuyo cuya cuyos cuyas qu'#195#169' qui'#195#169'n cu'#195#161'l cu'#195#161'les');
 Words('cu'#195#161'nto cu'#195#161'nta cu'#195#161'ntos cu'#195#161'ntas');
 Words('soy eres es somos sois son era eras '#195#169'ramos erais eran fui fuiste fue fuimos fuisteis');
 Words('fueron sido siendo ser sea seas seamos se'#195#161'is sean ser'#195#161' ser'#195#161'n');
 Words('ser'#195#173'a ser'#195#173'an');
 Words('estoy est'#195#161's est'#195#161' estamos est'#195#161'is est'#195#161'n estaba estabas');
 Words('est'#195#161'bamos estaban estado estar');
 Words('est'#195#169' est'#195#169's estemos est'#195#169'n estar'#195#161' estar'#195#161'n');
 Words('estar'#195#173'a tengo tienes tiene tenemos ten'#195#169'is');
 Words('tienen ten'#195#173'a ten'#195#173'an tuve tuvo tuvieron tenido tener tenga tengan');
 Words('tendr'#195#161' tendr'#195#161'n');
 Words('he has ha hemos hab'#195#169'is han hab'#195#173'a hab'#195#173'an hubo habido haber hay haya');
 Words('hayan habr'#195#161);
 Words('y e o u pero porque aunque sino si s'#195#173' no ni que como c'#195#179'mo cuando');
 Words('cu'#195#161'ndo donde d'#195#179'nde');
 Words('mientras entonces pues tambi'#195#169'n tampoco adem'#195#161's as'#195#173' a'#195#186'n aun');
 Words('ya todav'#195#173'a siempre nunca');
 Words('jam'#195#161's ahora hoy ayer ma'#195#177'ana antes despu'#195#169's luego pronto tarde');
 Words('temprano aqu'#195#173' ah'#195#173' all'#195#173);
 Words('all'#195#161' cerca lejos dentro fuera arriba abajo delante detr'#195#161's m'#195#161's mas');
 Words('menos muy tan tanto');
 Words('bien mal mejor peor solo sola solamente casi bastante demasiado quiz'#195#161's quiz'#195#161);
 Words('realmente');
 Words('de del a al en con sin por para desde hasta entre sobre bajo contra hacia seg'#195#186'n');
 Words('durante');
 Words('hola adi'#195#179's gracias favor perd'#195#179'n disculpa disculpe bienvenido bienvenida');
 Words('salud saludos');
 Words('buen bueno buena buenos buenas malo mala malos malas nuevo nueva nuevos nuevas');
 Words('viejo vieja viejos viejas joven j'#195#179'venes grande grandes peque'#195#177'o');
 Words('peque'#195#177'a peque'#195#177'os');
 Words('peque'#195#177'as bonito bonita bonitos bonitas hermoso hermosa feliz felices triste tristes');
 Words('f'#195#161'cil f'#195#161'ciles dif'#195#173'cil dif'#195#173'ciles importante importantes');
 Words('posible imposible necesario');
 Words('necesaria diferente diferencias igual iguales r'#195#161'pido r'#195#161'pida lento lenta');
 Words('primero primera');
 Words('primer '#195#186'ltimo '#195#186'ltima pr'#195#179'ximo pr'#195#179'xima largo larga corto');
 Words('corta alto alta bajo baja');
 Words('caliente fr'#195#173'o fr'#195#173'a limpio limpia abierto abierta cerrado cerrada libre');
 Words('gratis correcto');
 Words('correcta incorrecto verdadero verdadera falso falsa claro clara seguro segura');
 Words('mundo palabra palabras texto textos archivo archivos documento documentos l'#195#173'nea');
 Words('l'#195#173'neas');
 Words('p'#195#161'gina p'#195#161'ginas letra letras frase frases oraci'#195#179'n oraciones idioma');
 Words('idiomas lengua lenguas');
 Words('espa'#195#177'ol espa'#195#177'ola espa'#195#177'oles espa'#195#177'olas franc'#195#169's');
 Words('francesa ingl'#195#169's inglesa alem'#195#161'n alemana');
 Words('gram'#195#161'tica ortograf'#195#173'a error errores falta faltas correcci'#195#179'n');
 Words('correcciones diccionario');
 Words('diccionarios sugerencia sugerencias programa programas ordenador ordenadores computadora');
 Words('computadoras sistema sistemas informaci'#195#179'n datos entrada salida resultado resultados');
 Words('informe informes prueba pruebas versi'#195#179'n versiones opci'#195#179'n opciones comando');
 Words('comandos');
 Words('c'#195#179'digo fuente pantalla teclado rat'#195#179'n internet mensaje mensajes correo');
 Words('electr'#195#179'nico');
 Words('pregunta preguntas respuesta respuestas problema problemas soluci'#195#179'n soluciones');
 Words('ejemplo');
 Words('ejemplos ayuda n'#195#186'mero n'#195#186'meros nombre nombres direcci'#195#179'n direcciones');
 Words('tel'#195#169'fono tel'#195#169'fonos');
 Words('d'#195#173'a d'#195#173'as noche noches hora horas minuto minutos segundo segundos semana');
 Words('semanas mes');
 Words('meses a'#195#177'o a'#195#177'os tiempo tiempos lunes martes mi'#195#169'rcoles jueves viernes');
 Words('s'#195#161'bado domingo');
 Words('enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre');
 Words('cero uno dos tres cuatro cinco seis siete ocho nueve diez once doce cien ciento mil');
 Words('mill'#195#179'n millones persona personas hombre hombres mujer mujeres ni'#195#177'o');
 Words('ni'#195#177'os ni'#195#177'a ni'#195#177'as');
 Words('beb'#195#169' beb'#195#169's familia familias padre madre padres hijo hijos hija hijas hermano');
 Words('hermana');
 Words('abuelo abuela amigo amigos amiga amigas se'#195#177'or se'#195#177'ora se'#195#177'ores');
 Words('se'#195#177'orita gente');
 Words('casa casas hogar habitaci'#195#179'n habitaciones cuarto cuartos puerta puertas ventana');
 Words('ventanas');
 Words('mesa mesas silla sillas cama camas cocina ba'#195#177'o ba'#195#177'os jard'#195#173'n');
 Words('jardines escuela escuelas');
 Words('colegio universidad clase clases alumno alumnos alumna profesor profesora estudiante');
 Words('estudiantes lecci'#195#179'n lecciones libro libros cuaderno cuadernos l'#195#161'piz');
 Words('l'#195#161'pices papel');
 Words('ciudad ciudades pueblo pueblos pa'#195#173's pa'#195#173'ses calle calles camino caminos coche');
 Words('coches');
 Words('auto autos autob'#195#186's autobuses tren trenes avi'#195#179'n aviones barco barcos');
 Words('bicicleta bicicletas');
 Words('viaje viajes estaci'#195#179'n aeropuerto hospital oficina trabajo trabajos dinero precio');
 Words('precios');
 Words('tienda tiendas mercado mercados empresa empresas negocio negocios agua pan leche caf'#195#169);
 Words('t'#195#169);
 Words('fruta frutas manzana manzanas naranja naranjas pl'#195#161'tano arroz carne pescado huevo');
 Words('huevos');
 Words('patata patatas tomate tomates queso az'#195#186'car sal aceite comida desayuno almuerzo cena');
 Words('perro perros gato gatos animal animales caballo caballos p'#195#161'jaro p'#195#161'jaros pez');
 Words('peces');
 Words(#195#161'rbol '#195#161'rboles flor flores bosque monta'#195#177'a monta'#195#177'as');
 Words('r'#195#173'o r'#195#173'os mar playa sol luna estrella');
 Words('estrellas cielo tierra lluvia nieve viento fuego aire mano manos pie pies cabeza ojo');
 Words('ojos oreja orejas coraz'#195#179'n vida muerte amor paz m'#195#186'sica canci'#195#179'n');
 Words('canciones pel'#195#173'cula foto');
 Words('fotos imagen im'#195#161'genes juego juegos deporte equipo fiesta cumplea'#195#177'os Navidad');
 Words('Espa'#195#177'a Madrid');
 Words('M'#195#169'xico Argentina Chile Colombia Per'#195#186' Am'#195#169'rica Europa verano invierno');
 Words('primavera oto'#195#177'o');
 Words('rojo roja verde verdes azul azules amarillo amarilla blanco blanca negro negra gris');
 Words('rosa marr'#195#179'n color colores punto puntos parte partes lugar lugares cosa cosas');
 Words('raz'#195#179'n');
 Words('razones verdad historia historias idea ideas luz noche fuerza cara forma formas');
 Words('hacer hago haces hace hacemos hacen hice hizo hecho haciendo har'#195#169' har'#195#161);
 Words('hacemos');
 Words('ir voy vas va vamos vais van iba iban ido yendo vaya vayan fui fue fueron');
 Words('venir vengo vienes viene venimos vienen vino venido decir digo dices dice decimos');
 Words('dicen dijo dicho hablar hablo hablas habla hablamos hablan hablado hablando');
 Words('leer leo lees lee leemos leen le'#195#173'do leyendo escribir escribo escribes escribe');
 Words('escribimos escriben escrito escribiendo ver veo ves ve vemos ven visto viendo');
 Words('mirar miro miras mira miramos miran mirado escuchar escucho escucha escuchan escuchado');
 Words('saber s'#195#169' sabes sabe sabemos saben sab'#195#173'a sab'#195#173'a sabido conocer');
 Words('conozco conoce conocemos');
 Words('conocen conocido pensar pienso piensas piensa pensamos piensan pensado creer creo cree');
 Words('creemos creen cre'#195#173'do entender entiendo entiendes entiende entendemos entienden');
 Words('entendido');
 Words('comprender comprendo comprende comprenden comprendido aprender aprendo aprende aprendemos');
 Words('aprenden aprendido ense'#195#177'ar ense'#195#177'o ense'#195#177'a ense'#195#177'an');
 Words('ense'#195#177'ado querer quiero quieres quiere');
 Words('queremos quieren querido poder puedo puedes puede podemos pueden pod'#195#173'a');
 Words('podr'#195#173'an podido');
 Words('deber debo debes debe debemos deben debido necesitar necesito necesita necesitamos');
 Words('necesitan necesitado gustar gusta gustan gustado amar amo amas ama amamos aman amado');
 Words('comer como comes come comemos comen comido comiendo beber bebo bebes bebe bebemos beben');
 Words('bebido vivir vivo vives vive vivimos viven vivido dormir duermo duerme duermen dormido');
 Words('trabajar trabajo trabajas trabaja trabajamos trabajan trabajado estudiar estudio estudias');
 Words('estudia estudiamos estudian estudiado jugar juego juegas juega jugamos juegan jugado');
 Words('correr corro corre corren corrido caminar camino camina caminan caminado comprar compro');
 Words('compra compran comprado vender vendo vende venden vendido pagar pago paga pagan pagado');
 Words('dar doy das da damos dan dado tomar tomo toma toman tomado llevar llevo lleva llevan');
 Words('llevado traer traigo trae traen tra'#195#173'do poner pongo pones pone ponemos ponen puesto');
 Words('salir salgo sale salen salido llegar llego llega llegan llegado pasar paso pasa pasan');
 Words('pasado quedar quedo queda quedan quedado dejar dejo deja dejan dejado buscar busco busca');
 Words('buscan buscado encontrar encuentro encuentra encuentran encontrado esperar espero espera');
 Words('esperan esperado ayudar ayudo ayuda ayudan ayudado abrir abro abre abren abierto');
 Words('cerrar cierro cierra cierran cerrado empezar empiezo empieza empiezan empezado terminar');
 Words('termino termina terminan terminado cambiar cambio cambia cambian cambiado usar uso usa');
 Words('usan usado corregir corrijo corrige corrigen corregido comprobar compruebo comprueba');
 Words('guardar guardo guarda guardan guardado enviar env'#195#173'o env'#195#173'a env'#195#173'an');
 Words('enviado recibir recibo');
 Words('recibe reciben recibido volver vuelvo vuelve vuelven vuelto recordar recuerdo recuerda');
 Words('olvidar olvido olvida olvidado repetir repito repite repetido pedir pido pide pedido');
 Words('gracias actualmente especialmente probablemente simplemente r'#195#161'pidamente lentamente');
 Words('correctamente finalmente completamente f'#195#161'cilmente completamente ping'#195#188'ino');
 Words('ping'#195#188'inos');
 Words('verg'#195#188'enza biling'#195#188'e ling'#195#188#195#173'stica tambi'#195#169'n');
 Words('despu'#195#169's atenci'#195#179'n acci'#195#179'n canci'#195#179'n estaci'#195#179'n');
 Words('ola olas ano anos papa pap'#195#161' mama mam'#195#161' si s'#195#173' el '#195#169'l tu');
 Words('t'#195#186' mi m'#195#173' te t'#195#169' de d'#195#169' se s'#195#169);
End;

Procedure ItalianWords;
Begin
 Words('io tu lui lei noi voi loro mi ti ci vi si s'#195#169' me te gli le lo la li ne');
 Words('il i l un uno una un altro altra altri altre questo questa questi queste quello quella');
 Words('quelli quelle ci'#195#178' ogni qualche qualsiasi ciascuno ciascuna tutto tutta tutti tutte');
 Words('nessuno nessuna qualcuno qualcuna qualcosa niente nulla molto molta molti molte poco');
 Words('poca pochi poche tanto tanta tanti tante troppo troppa troppi troppe stesso stessa');
 Words('stessi stesse mio mia miei mie tuo tua tuoi tue suo sua suoi sue nostro nostra nostri');
 Words('nostre vostro vostra vostri vostre chi che cui quale quali quanto quanta quanti quante');
 Words('sono sei '#195#168' siamo siete era eri eravamo eravate erano fui fu fummo furono stato stata');
 Words('stati state essere essendo sia siano sar'#195#160' saranno sarei sarebbe sarebbero');
 Words('ho hai ha abbiamo avete hanno avevo aveva avevamo avevate avevano avuto avere avendo');
 Words('abbia abbiano avr'#195#160' avranno avrei avrebbe ebbe ebbero sto stai sta stiamo state stanno');
 Words('stavo stava stavano stato stare stia stiano e ed o oppure ma per'#195#178' perch'#195#169);
 Words('poich'#195#169' quindi');
 Words('dunque anche ancora gi'#195#160' sempre mai non n'#195#169' s'#195#172' no forse certamente');
 Words('davvero proprio solo');
 Words('soltanto quasi abbastanza cos'#195#172' pi'#195#185' meno troppo bene male meglio peggio come');
 Words('dove quando');
 Words('mentre se senza purch'#195#169' bench'#195#169' affinch'#195#169' cio'#195#168' oggi ieri');
 Words('domani adesso ora prima dopo poi');
 Words('presto tardi subito spesso talvolta qui qua l'#195#172' l'#195#160' dentro fuori sopra sotto');
 Words('davanti');
 Words('dietro vicino lontano insieme attraverso durante contro verso fino tra fra con su per');
 Words('a ad da di in del dello della dei degli delle al allo alla ai agli alle dal dallo');
 Words('dalla dai dagli dalle nel nello nella nei negli nelle sul sullo sulla sui sugli sulle');
 Words('col coi d all dell dall nell sull quest quell sant c m t s v po');
 Words('ciao buongiorno buonasera buonanotte arrivederci salve grazie prego favore scusa scusi');
 Words('benvenuto benvenuta auguri salute piacere buono buona buoni buone buon cattivo cattiva');
 Words('bello bella belli belle bel brutto brutta grande grandi piccolo piccola piccoli piccole');
 Words('nuovo nuova nuovi nuove vecchio vecchia vecchi vecchie giovane giovani felice felici');
 Words('triste tristi facile facili difficile difficili importante importanti possibile impossibile');
 Words('necessario necessaria diverso diversa uguale uguali giusto giusta sbagliato sbagliata');
 Words('vero vera falso falsa libero libera gratuito gratuita aperto aperta chiuso chiusa');
 Words('lungo lunga corto corta alto alta basso bassa caldo calda freddo fredda veloce lento');
 Words('lenta chiaro chiara pulito pulita vuoto vuota pieno piena pronto pronta sicuro sicura');
 Words('mondo parola parole testo testi file documento documenti riga righe pagina pagine');
 Words('lettera lettere frase frasi lingua lingue italiano italiana italiani italiane francese');
 Words('inglese tedesco spagnolo grammatica ortografia errore errori correzione correzioni');
 Words('correttore dizionario dizionari suggerimento suggerimenti programma programmi codice');
 Words('sorgente computer sistema sistemi informazione informazioni dati ingresso uscita risultato');
 Words('risultati rapporto rapporti prova prove versione versioni opzione opzioni comando comandi');
 Words('schermo tastiera mouse rete internet sito siti messaggio messaggi posta elettronica');
 Words('domanda domande risposta risposte problema problemi soluzione soluzioni esempio esempi');
 Words('aiuto numero numeri nome nomi indirizzo indirizzi telefono telefoni giorno giorni notte');
 Words('notti mattina pomeriggio sera settimana settimane mese mesi anno anni ora ore minuto');
 Words('minuti secondo secondi tempo tempi luned'#195#172' marted'#195#172' mercoled'#195#172);
 Words('gioved'#195#172' venerd'#195#172' sabato domenica');
 Words('gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre');
 Words('dicembre zero uno due tre quattro cinque sei sette otto nove dieci undici dodici cento');
 Words('mille milione milioni primo prima primi prime ultimo ultima ultimi ultime prossimo');
 Words('prossima persona persone uomo uomini donna donne bambino bambini bambina bambine ragazzo');
 Words('ragazzi ragazza ragazze amico amici amica amiche famiglia famiglie padre madre genitori');
 Words('figlio figli figlia figlie fratello fratelli sorella sorelle nonno nonna signore signora');
 Words('casa case stanza stanze camera camere porta porte finestra finestre tavolo tavoli sedia');
 Words('sedie letto letti cucina bagno bagni giardino giardini scuola scuole classe classi');
 Words('studente studenti studentessa insegnante professore professoressa universit'#195#160' libro');
 Words('libri');
 Words('quaderno quaderni penna penne matita matite carta citt'#195#160' paese paesi strada strade via');
 Words('vie');
 Words('macchina macchine automobile automobili auto autobus treno treni aereo aerei nave navi');
 Words('barca barche bicicletta biciclette viaggio viaggi stazione aeroporto ufficio ospedale');
 Words('lavoro lavori denaro soldi prezzo prezzi negozio negozi mercato mercati azienda aziende');
 Words('acqua pane latte caff'#195#168' t'#195#168' frutta mela mele arancia arance banana riso carne');
 Words('pesce uovo');
 Words('uova patata patate pomodoro pomodori formaggio zucchero sale olio cibo colazione pranzo');
 Words('cena pasta pizza vino birra cane cani gatto gatti animale animali cavallo cavalli uccello');
 Words('uccelli albero alberi fiore fiori bosco montagna montagne fiume fiumi mare spiaggia sole');
 Words('luna stella stelle cielo terra pioggia neve vento fuoco aria mano mani piede piedi testa');
 Words('occhio occhi orecchio orecchie cuore vita morte amore pace musica canzone canzoni film');
 Words('fotografia fotografie foto immagine immagini gioco giochi sport squadra festa compleanno');
 Words('Natale Italia Roma Milano Venezia Napoli Europa estate inverno primavera autunno rosso');
 Words('rossa verde verdi blu azzurro azzurra giallo gialla bianco bianca nero nera grigio grigia');
 Words('rosa marrone colore colori punto punti parte parti luogo luoghi cosa cose ragione ragioni');
 Words('verit'#195#160' storia storie idea idee luce forza faccia forma forme qualit'#195#160);
 Words('quantit'#195#160' capacit'#195#160);
 Words('fare faccio fai fa facciamo fate fanno fatto facendo feci fece far'#195#178' far'#195#160);
 Words('farebbe');
 Words('andare vado vai va andiamo andate vanno andato andata andando venire vengo vieni viene');
 Words('veniamo venite vengono venuto venuta dire dico dici dice diciamo dite dicono detto');
 Words('parlare parlo parli parla parliamo parlate parlano parlato parlando leggere leggo leggi');
 Words('legge leggiamo leggete leggono letto leggendo scrivere scrivo scrivi scrive scriviamo');
 Words('scrivete scrivono scritto scrivendo vedere vedo vedi vede vediamo vedete vedono visto');
 Words('guardare guardo guarda guardiamo guardano guardato ascoltare ascolto ascolta ascoltano');
 Words('ascoltato sapere so sai sa sappiamo sapete sanno sapevo saputo conoscere conosco conosci');
 Words('conosce conosciamo conoscete conoscono conosciuto pensare penso pensi pensa pensiamo');
 Words('pensano pensato credere credo crede crediamo credono creduto capire capisco capisci');
 Words('capisce capiamo capite capiscono capito comprendere comprendo comprende compreso');
 Words('imparare imparo impara impariamo imparano imparato insegnare insegno insegna insegnato');
 Words('volere voglio vuoi vuole vogliamo volete vogliono voluto vorrei vorrebbe potere posso');
 Words('puoi pu'#195#178' possiamo potete possono potuto potrei potrebbe dovere devo devi deve');
 Words('dobbiamo');
 Words('dovete devono dovuto dovrei dovrebbe piacere piace piacciono piaciuto amare amo ama');
 Words('amiamo amano amato mangiare mangio mangi mangia mangiamo mangiate mangiano mangiato');
 Words('bere bevo bevi beve beviamo bevete bevono bevuto vivere vivo vivi vive viviamo vivete');
 Words('vivono vissuto dormire dormo dormi dorme dormiamo dormite dormono dormito lavorare lavoro');
 Words('lavori lavora lavoriamo lavorate lavorano lavorato studiare studio studi studia studiamo');
 Words('studiate studiano studiato giocare gioco gioca giochiamo giocano giocato correre corro');
 Words('corre corrono corso camminare cammino cammina camminano camminato comprare compro compra');
 Words('comprano comprato vendere vendo vende vendono venduto pagare pago paga pagano pagato');
 Words('dare do dai d'#195#160' diamo date danno dato prendere prendo prendi prende prendiamo prendono');
 Words('preso portare porto porta portano portato mettere metto metti mette mettiamo mettono');
 Words('messo uscire esco esci esce usciamo uscite escono uscito arrivare arrivo arriva arrivano');
 Words('arrivato passare passo passa passano passato restare resto resta restano restato');
 Words('lasciare lascio lascia lasciamo lasciano lasciato cercare cerco cerca cercano cercato');
 Words('trovare trovo trovi trova troviamo trovano trovato aspettare aspetto aspetta aspettano');
 Words('aspettato aiutare aiuto aiuta aiutiamo aiutano aiutato aprire apro apri apre apriamo');
 Words('aprono aperto chiudere chiudo chiudi chiude chiudiamo chiudono chiuso iniziare inizio');
 Words('inizia iniziano iniziato finire finisco finisci finisce finiamo finiscono finito');
 Words('cambiare cambio cambia cambiamo cambiano cambiato usare uso usa usiamo usano usato');
 Words('correggere correggo corregge correggono corretto corretta controllare controllo controlla');
 Words('controllato salvare salvo salva salvano salvato inviare invio invia inviano inviato');
 Words('ricevere ricevo riceve ricevono ricevuto tornare torno torna tornano tornato ricordare');
 Words('ricordo ricorda ricordano ricordato dimenticare dimentico dimentica dimenticato chiedere');
 Words('chiedo chiedi chiede chiediamo chiedono chiesto rispondere rispondo risponde risposto');
 Words('scegliere scelgo sceglie scelgono scelto tenere tengo tiene tengono tenuto perdere perso');
 Words('soprattutto purtroppo infatti invece inoltre comunque dunque allora veramente facilmente');
 Words('rapidamente lentamente correttamente finalmente completamente probabilmente sicuramente');
 Words('attenzione azione stazione lezione lezioni emozione emozioni informatica tecnologia');
 Words('perch'#195#169' affinch'#195#169' poich'#195#169' bench'#195#169' '#195#168' s'#195#172);
 Words('n'#195#169' s'#195#169' t'#195#168' d'#195#160' gi'#195#160' gi'#195#185' pi'#195#185);
 Words('l'#195#172' l'#195#160' per'#195#178' cio'#195#168' caff'#195#168);
End;

Procedure InitDictionary;
Var A,B: Integer; W: TWord;
Begin
 WordCount := 0;
 If DictName='fr_FR' Then FrenchWords
 Else If DictName='de_DE' Then GermanWords
 Else If DictName='es_ES' Then SpanishWords
 Else If DictName='it_IT' Then ItalianWords Else EnglishWords;
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
 L,H,M,P: Integer;
 K: TWord;
 AllUpper: Boolean;
Begin
 AllUpper := True;
 For P := 1 To Length(W) Do Begin
  If W[P] In ['a'..'z'] Then AllUpper := False;
  If (Ord(W[P])=195) And (P<Length(W)) Then
   If Ord(W[P+1]) In [159..182,184..190] Then AllUpper := False
 End;
 W := Lower(W); L := 1; H := WordCount; Known := False;
 While L<=H Do Begin
  M := (L+H) Div 2; K := Lower(Dictionary[M]^);
  If W=K Then Begin
   Known := True; Exit
  End;
  If W<K Then H := M-1 Else L := M+1
 End;
 { In German uppercase text, SS is also a valid rendering of sharp s. }
 If (DictName='de_DE') And AllUpper Then
  For M := 1 To WordCount Do Begin
   K := Lower(Dictionary[M]^); P := Pos(#195#159,K);
   While P>0 Do Begin Delete(K,P,2); Insert('ss',K,P); P := Pos(#195#159,K) End;
   If W=K Then Begin Known := True; Exit End
  End
End;

Function RankingKey(W: TWord): TWord;
Var P: Integer;
Begin
 W := Lower(W);
 If DictName='de_DE' Then Begin
  P := Pos(#195#159,W);
  While P>0 Do Begin Delete(W,P,2); Insert('ss',W,P); P := Pos(#195#159,W) End
 End;
 If DictName='es_ES' Then Begin
  { Keep the Spanish letter enye distinct from n in suggestion ranking. }
  P := Pos(#195#177,W);
  While P>0 Do Begin Delete(W,P,2); Insert('~',W,P); P := Pos(#195#177,W) End
 End;
 RankingKey := Fold(W)
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
   If B In [159..182,184..190] Then AllUpper := False;
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
    If B=159 Then Begin
     Delete(S,P-1,2); Insert('SS',S,P-1)
    End;
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
 SuggestionCount := 0; W := Lower(W); F := RankingKey(W);
 Preferred := '';
 If DictName='fr_FR' Then Begin
 If W='bonjours' Then Preferred := 'bonjour';
 If W='beaucoups' Then Preferred := 'beaucoup';
 If W='malgres' Then Preferred := 'malgr'#195#169;
 If W='parmis' Then Preferred := 'parmi';
 If W='biensur' Then Preferred := 'bien s'#195#187'r';
 End Else If DictName='de_DE' Then Begin
  If W='hlo' Then Preferred := 'Hallo';
  If W='wlet' Then Preferred := 'Welt';
  If W='dsa' Then Preferred := 'das';
  If W='udn' Then Preferred := 'und';
  If W='nciht' Then Preferred := 'nicht';
  If W='deutch' Then Preferred := 'deutsch';
  If W='deutsh' Then Preferred := 'deutsch';
  If W='strasse' Then Preferred := 'Stra'#195#159'e';
  If W='grusse' Then Preferred := 'Gr'#195#188#195#159'e';
  If W='gruesse' Then Preferred := 'Gr'#195#188#195#159'e';
  If W='fuer' Then Preferred := 'f'#195#188'r';
  If W='ueber' Then Preferred := #195#188'ber';
  If W='schoen' Then Preferred := 'sch'#195#182'n';
  If W='haeuser' Then Preferred := 'H'#195#164'user';
  If W='koennen' Then Preferred := 'k'#195#182'nnen';
  If W='moechte' Then Preferred := 'm'#195#182'chte';
  If W='schones' Then Preferred := 'sch'#195#182'nes';
  If W='bischen' Then Preferred := 'bisschen';
  If W='nemlich' Then Preferred := 'n'#195#164'mlich'
 End Else If DictName='es_ES' Then Begin
  If W='holaa' Then Preferred := 'hola';
  If W='mndo' Then Preferred := 'mundo';
  If W='gracais' Then Preferred := 'gracias';
  If W='espanol' Then Preferred := 'espa'#195#177'ol';
  If W='nino' Then Preferred := 'ni'#195#177'o';
  If W='ninos' Then Preferred := 'ni'#195#177'os';
  If W='ninia' Then Preferred := 'ni'#195#177'a';
  If W='maniana' Then Preferred := 'ma'#195#177'ana';
  If W='correcion' Then Preferred := 'correcci'#195#179'n';
  If W='diccionarioo' Then Preferred := 'diccionario';
  If W='haver' Then Preferred := 'haber';
  If W='tamvien' Then Preferred := 'tambi'#195#169'n';
  If W='pinguino' Then Preferred := 'ping'#195#188'ino';
  If W='verguenza' Then Preferred := 'verg'#195#188'enza'
 End Else If DictName='it_IT' Then Begin
  If W='ciaoo' Then Preferred := 'ciao';
  If W='mndo' Then Preferred := 'mondo';
  If W='grazzie' Then Preferred := 'grazie';
  If W='italaino' Then Preferred := 'italiano';
  If W='perche' Then Preferred := 'perch'#195#169;
  If W='caffe' Then Preferred := 'caff'#195#168;
  If W='piu' Then Preferred := 'pi'#195#185;
  If W='lunedi' Then Preferred := 'luned'#195#172;
  If W='citta' Then Preferred := 'citt'#195#160;
  If W='universita' Then Preferred := 'universit'#195#160;
  If W='sopratutto' Then Preferred := 'soprattutto';
  If W='pultroppo' Then Preferred := 'purtroppo';
  If W='qualita' Then Preferred := 'qualit'#195#160;
  If W='correzzione' Then Preferred := 'correzione'
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
  K := RankingKey(Dictionary[N]^);
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
 If S=#225#186#158 Then IsLetter := True;
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
 WriteLn('HUNSPELL 1.4 - Cette commande permet de lancer le correcteur autonome de '+
        'francais, anglais, allemand, espagnol et italien.');
 WriteLn;
 WriteLn('Syntaxe: hunspell [-d fr_FR|en_US|en_GB|de_DE|es_ES|it_IT] [-l | -U] document.txt');
 WriteLn;
 WriteLn('  -d fr_FR      Lexique francais embarque (valeur par defaut)');
 WriteLn('  -d en_US      Lexique anglais americain embarque');
 WriteLn('  -d en_GB      Lexique anglais britannique embarque');
 WriteLn('  -d de_DE      Lexique allemand embarque');
 WriteLn('  -d es_ES      Lexique espagnol embarque');
 WriteLn('  -d it_IT      Lexique italien embarque');
 WriteLn('  -l            Afficher seulement les mots suspects');
 WriteLn('  -U            Afficher le texte corrige par la premiere suggestion');
 WriteLn('  -h, --help, /? Aide');
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
  If (Arg='--help') Or (Arg='-h') Or (Arg='/?') Then Begin
   Help; Halt(0)
  End
  Else If (Arg='--version') Or (Arg='-v') Then Begin
   WriteLn('HUNSPELL Pascal 1.4 (implementation independante)'); Halt(0)
  End Else If Arg='-D' Then Begin
   WriteLn('fr_FR (francais, embarque, lexique reduit)');
   WriteLn('en_US (anglais americain, embarque, lexique reduit)');
   WriteLn('en_GB (anglais britannique, embarque, lexique reduit)');
   WriteLn('de_DE (allemand, embarque, lexique reduit)');
   WriteLn('es_ES (espagnol, embarque, lexique reduit)');
   WriteLn('it_IT (italien, embarque, lexique reduit)'); Halt(0)
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
 If (DictName<>'fr_FR') And (DictName<>'en_US') And (DictName<>'en_GB') And
    (DictName<>'de_DE') And (DictName<>'es_ES') And (DictName<>'it_IT') Then
  Fail('lexique inconnu: utiliser fr_FR, en_US, en_GB, de_DE, es_ES ou it_IT');
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
