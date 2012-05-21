Pro �sp�n� zprovozn�n� mnou naimplementovan� knihovny, kter� spravuje p��stupov� pr�va, mus�te nejprve nainstalovat software, na kter�m je knihovna z�visl�. 
Jedn� se o:
� Ruby prost�ed� - http://www.ruby-lang.org/en/downloads/
    Na p��slu�n� str�nce vyberte distribuci podle va�eho opera�n�ho syst�mu. Pro windows je nejlep�� �e�en� RubyInstaller. Nainstalujte nejnov�j�� verzi. V dob� vyd�n� knihovny byla nejnov�j�� verze Ruby 1.9.3.-p194.  P�i instala ci za�krtn�te "Add Ruby executables to your PATH".
� JDK 
    http://www.oracle.com/technetwork/java/javase/downloads/jdk-7u4-downloads-1591156.html
    Datab�ze eXist-db pro sv�j b�h pot�ebuje Java Development Kit. JRE nen� dosta�uj�c�.
� Datab�zi eXist-db - http://exist-db.org/exist/download.xml
    Doporu�uji st�hnout "Stable release". V dob� vyd�n� byla dostupn� verze eXist-setup-1.4.2-rev16251.

D�le pot�ebujete nainstalovat samotnou knihovnu a eXistAPI rozhran�.
Nejjednodu���m zp�sobem, jak nainstalovat knihovnu a komunika�n� rozhran� pro eXist-db, je nainstalovat Ruby prost�ed� v�etn� bal��kovac�ho syst�mu gem a nainstalovat jak knihovnu, tak rozhran� pomoc� p��kaz� "gem install Ruby-ACL" (poml�ka je podstatn�, proto�e "rubyacl" je gem, kter� s moj� knihovnou nem� nic spole�n�ho) a "gem install eXistAPI". P��kazy lze pou��t ve standartn� p��kazov� ��dce, pokud jste za�krtli p�i instalaci volbu "Add Ruby executables to your PATH". 

Dal��m zp�sobem, jak pou��vat knihovnu s rozhran�m je, st�hnout si zdrojov� k�dy bu� z CD nebo z githubu. Zdrojov� k�dy Ruby-ACL se nach�z� na https://github.com/sirljan/Ruby-ACL a zdrojov� k�dy eXistAPI jsou na https://github.com/sirljan/eXistAPI. V p��pad� sta�en� k�du z githubu je d�le�it� pou��t p��kaz "require" se spr�vnou adresou ke zdrojov�m soubor�m. 

Pozn�mka: V�choz� adresy, ze kter�ch "require" vkl�d� soubory, jsou aktu�ln� adres�� a adres��, kde se ukl�daj� gem. Proto, kdy� si gem nainstalujete p�es rubygem, nen� pot�eba �e�it adresy, sta�� pou��t p��kazy "require 'Ruby-AL'" a "require 'eXistAPI'".

P�ed pou�it�m spus�te eXist-db. Funk�nost m��ete ov��it t�eba v irb - Interactive Ruby Shell zavol�n�m p��kaz�:
require 'Ruby-ACL'
require 'eXistAPI'
@db = ExistAPI.new("http://localhost:8080/exist/xmlrpc", "admin", "password")
@my_acl = RubyACL.new("my_acl", @db)
@my_acl.create_principal("Sheldon")

Po spu�t�n� t�chto p��kaz� najdete pomoc� eXist Admin Clientu, v kolekci "/db/acl/" dokument  Principals.xml, ve kter�m by m�l b�t (jako posledn� v uzlu Individuals) uzel s id="Sheldon". Pokud uzel v dokumentu nen�, n�co bylo chybn� provedeno.



OBSAH P�ILO�EN�HO CD
.
|-- abstract                     - adres�� s abstraktem v �j a aj
|   |-- abstract.html            - kr�tky abstract
|   |-- RabstractAJ.html         - roz���en� abstract v angli�tin�
|   `-- RabstractCZ.html         - roz���en� abstract v �e�tin�
|-- gem                          - adres�� obsahuj�c� instala�n� bal��ky gem
|-- index.html                   - v�choz� str�nka projektu - z n� realtivn� 
|                                html odkazy na dokumentaci, zdrojov� 
|                                texty a exe soubor
|-- install.TXT                  - postup instalace knihovny
|-- rdoc                         - adres�� s rdoc dokumentac�
|   |-- eXistAPI                 - rdoc dokumentace k eXistAPI
|   |   |-- index.html           - v�choz� str�nka dokumentace eXistAPI  
|   |   `-- ...                  - dal�� soubory a str�nky dokumentace
|   |   |-- images               - obr�zky/ikony dokumentace
|   |   |   `-- ...
|   `-- Ruby-ACL                 - rdoc dokumentace k Ruby-ACL
|       |-- index.html           - v�choz� str�nka dokumentace Ruby-ACL 
|       `-- ...                  - dal�� soubory a str�nky dokumentace
|       |-- images               - obr�zky/ikony dokumentace
|           `-- ...
|-- readme.TXT                   - popis, co ve kter�m adres��i je a jak� je ��el jednotliv�ch soubor�, postup spu�t�n�
|-- src                          - adres�� zdrojov�ch soubor� eXistAPI a Ruby-ACL
|   |-- eXistAPI
|   |   `-- ...                  - zdrojov� soubory eXistAPI
|   `-- Ruby-ACL                        
|       |-- ...                  - zdrojov� soubory Ruby-ACL
|       `-- src_files                   
|           `-- ...              - datov� XML soubory a jejich DTD
`-- text                         - adres�� obsahuj�c� vlastn� text BP
    `-- sirljan-thesis-2012.pdf  - text BP ve form�tu PDF
    
18 directories, 122 files