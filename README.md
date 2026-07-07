# Hardware Particle Engine & HD VGA Controller pe FPGA (Xilinx Basys 3)

## 1. Denumirea și Obiectivul Proiectului
**Denumire:** Sistem Interactiv de Afișare Grafică HD și Fizică 2D pe Monitor VGA (Hardware Particle Engine & VGA Driver)  
**Cadru de lucru:** Proiect de practică / laborator (Program 09:30 – 13:30)  
**Obiectiv:** Proiectarea și implementarea de la zero, exclusiv în limbajul de descriere hardware **Verilog**, a unui driver video VGA personalizabil și a unui motor hardware de fizică 2D pe placa de dezvoltare **Digilent Basys 3** (cip **AMD / Xilinx Artix-7**).

Sistemul elimină complet nevoia unui microprocesor, a unui sistem de operare sau a librăriilor software externe, executând generarea semnalelor video, accesul concurent în memorie și calculele cinematice strict la nivel de logică digitală și paralelism hardware.

---

## 2. Arhitectura și Alegerea Platformei Basys 3
Placa **Basys 3** este optimizată pentru proiecte de procesare grafică și interfațare digitală datorită următoarelor resurse hardware:
* **Convertor Digital-Analog (DAC) VGA pe 12 biți:** Format dintr-o rețea de rezistoare care oferă 4 biți per canal (RGB 4-4-4), permițând afișarea simultană a 4096 de culori distincte.
* **Afișaj cu 7 Segmente (Anod Comun):** 4 cifre controlate prin logică **Active-Low (Activ în 0)**, utilizate pentru afișarea metadatelor în timp real (număr de particule active, scor, coordonate) fără a consuma resurse pe monitor.
* **Interfață de Control UI:** 5 butoane push dispuse tip D-Pad (pentru mișcare pe axe carteziene) și 16 switch-uri (pentru controlul gravitației, paletei cromatice și modului de coliziune).
* **Conectori de Extensie Pmod:** 4 porturi de intrare/ieșire pentru interfațarea senzorilor externi (accelerometru, giroscop) prin protocoale seriale (I2C / SPI).

---

## 3. Metodologia de Dezvoltare și Etapele Proiectului
Dezvoltarea sistemului respectă un flux industrial standard, pornind de la validarea prin **simulare RTL (Testbench)** înainte de programarea pe siliciu, pentru a izola erorile logice de eventualele probleme electrice sau de rutare.

### Etapa 1 (Săptămâna 1): Baza Comună — Simularea RTL și Driver-ul VGA 640x480
**Obiectiv:** Proiectarea generatorului de sincronizare video, validarea timpiilor în simulator și afișarea unui semnal de test stabil pe monitor (VESA 640x480 @ 60 Hz).

* **Simularea RTL (Testbench-First):** Înaintea încărcării pe placă, modulul `vga_sync` este testat prin simulare în Vivado Simulator. Se verifică pe formele de undă că lățimea impulsurilor `HSYNC` (sincronizare orizontală) și `VSYNC` (sincronizare verticală), precum și perioadele de Front Porch / Back Porch, corespund exact standardului VESA.
* **Diviziunea de Ceas:** Ceasul master de **100 MHz** al plăcii este divizat la **25.175 MHz** prin logică RTL sau Vivado Clocking Wizard, obținându-se ceasul de scanare a pixelilor (`pixel_clk`).
* **Maparea Pinilor (`.xdc`):** Conectarea variabilelor din Verilog la pinii fizici ai mufei VGA și la ceasul de sistem conform specificațiilor Basys 3.
* **Validare Hardware:** Odată ce simularea confirmă timpii corecți, proiectul este sintetizat și încărcat pe FPGA. Testul de succes constă în generarea unui ecran complet roșu (`4'b1111`) sau a unei grile de culori (test-pattern) perfect stabile.
* **Jurnal de depanare (Săptămâna 1):**
  * *(Se va completa cu eventualele ajustări de timing din simulator și rezolvarea decalajelor pe monitor).*

---

### Etapa 2 (Săptămâna 2): Generarea de Figuri Geometrice și Scalarea la HD Ready (720p)
**Obiectiv:** Depășirea nivelului de bază prin trecerea de la forme statice simple la calculul matematic al figurilor pe ecran și scalarea rezoluției la **1280x720p HD @ 60 Hz**.

* **Sinteza de Ceas pentru Înaltă Definiție (HD Scaling):** Se reconfigurează modulul IP Clocking Wizard (MMCM/PLL) pentru a multiplica frecvența internă de la **100 MHz** la **~74.25 MHz**, frecvența de pixeli necesară standardului HD Ready (720p). Se recalculează numărătoarele pentru rezoluția activă de $1280 \times 720$ pixeli.
* **Modelarea Matematică a Formelor:** În loc de dreptunghiuri simple bazate pe limite carteziene, se implementează generarea unui cerc solid prin evaluarea ecuației geometrice direct pe fluxul video:
  $$(x - x_0)^2 + (y - y_0)^2 \le r^2$$
  *(Unde $x_0, y_0$ reprezintă coordonatele centrului controlate din darurile de pe placă, iar $r$ este raza constantă).*
* **Sincronizare pe Vertical Blanking:** Pentru a preveni efectul de rupere a imaginii (tearing/ghosting) la mișcarea figurilor din butoane, actualizarea registrelor de coordonate se condiționează strict de frontul semnalului `VSYNC`.
* **Jurnal de depanare (Săptămâna 2):**
  * *(Se va completa cu provocările întâmpinate la scalarea frecvenței la 74.25 MHz și optimizarea calculului de raze în Verilog).*

---

### Etapa 3 (Săptămâna 3): Elementul Unic — Hardware Particle Engine, BRAM și Interfață UI
**Obiectiv:** Diferențierea prin complexitate arhitecturală: transformarea figurii simple într-un motor de particule cu cinematică concurentă, stocare în memorie Block RAM și interfață de vizualizare hardware.

* **Fizica Particulelor și Coliziuni Elastice:** Modulul `particle_engine` gestionează un sistem dinamic de obiecte care accelerează continuu sub acțiunea unei constante gravitaționale ($V = V_0 + gt$) și ricoșează la impactul cu frontierele ecranului 720p. Calculele se efectuează în virgulă fixă (Fixed-Point Math) folosind operații de deplasare pe biți (bit-shifting) pentru a economisi celulele DSP.
* **Arhitectură True Dual-Port BRAM:** Gestiunea pozițiilor și vitezelor pentru multiple particule simultan necesită lățime de bandă crescută. Se instanțiază o memorie statică internă (Block RAM) cu două porturi independente de acces:
  * **Portul A:** Alocat exclusiv controller-ului video, care citește la frecvența de scanare (**74.25 MHz**) pentru a desena particulele pe monitor.
  * **Portul B:** Alocat exclusiv motorului de fizică, care actualizează coordonatele și vitezele în fundal fără a intra în conflict (contention) cu citirea video.
* **Interfațarea Afișajului cu 7 Segmente (Active-Low):** Implementarea unui decodificator și multiplexor pe timpi pentru cele 4 cifre cu anod comun ale plăcii. Sistemul utilizează semnale de 0 logic (`1'b0`) pe anozi (`an[3:0]`) și pe catozi (`seg[6:0]`) pentru a afișa în timp real numărul de particule active pe ecran sau viteza de impact.
* **Extensie Hardware Opțională (Senzor Pmod):** Integrarea unui accelerometru extern prin conectorii Pmod pentru a controla direcția gravitației de pe ecran direct prin înclinarea fizică a plăcii Basys 3.
* **Jurnal de depanare (Săptămâna 3):**
  * *(Se va completa cu detalii privind arbitrarea accesului în memoria BRAM și sincronizarea dintre mașina de stări a fizicii și afișajul cu 7 segmente).*

---

## 4. Structura Proiectului și Organizarea pe GitHub
Repository-ul este organizat conform standardelor de dezvoltare hardware din industrie, excludând fișierele de temporar generate de Vivado (`.runs`, `.cache`, `.sim`, `.hw`) pentru a garanta portabilitatea și curățenia codului pe altă stație de lucru:

```text
Proiect-Capgemini/
│
├── Proiect/
│   ├── Proiect.xpr                  # Fișierul principal de proiect Vivado
│   │
│   ├── .srcs/
│   │   ├── sources_1/new/
│   │   │   ├── top_module.v         # Modulul principal de interfațare (Top Level RTL)
│   │   │   ├── vga_sync.v           # Generatorul semnalelor HSYNC, VSYNC (VESA / HD)
│   │   │   ├── display_controller.v # Multiplexorul video și generatorul de figuri
│   │   │   ├── particle_engine.v    # Mașina cu stări (FSM) pentru fizică și coliziuni
│   │   │   └── seg7_controller.v    # Multiplexorul Active-Low pentru afișajul cu 7 segmente
│   │   │
│   │   └── constrs_1/new/
│   │       └── basys3.xdc           # Constrângerile fizice pentru pinii Xilinx Artix-7
│   │
│   └── .gitignore                   # Excluderea directoarelor locale temporare
│
└── README.md                        # Documentația tehnică a arhitecturii