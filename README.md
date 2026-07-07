# Proiect de Practică: Driver VGA și Motor Grafic pe FPGA (Xilinx Basys 3)

## 1. Denumirea și Obiectivul Proiectului
**Denumire:** Sistem Interactiv de Afișare Grafică și Fizică 2D pe Monitor VGA (Hardware Particle Engine & VGA Driver)
**Cadru de lucru:** Proiect de practică / laborator (Program 09:30 – 13:30)
**Obiectiv:** Conectarea plăcii de dezvoltare **Digilent Basys 3** (echipată cu cipul FPGA **Xilinx Artix-7**) la un monitor prin portul VGA și generarea de grafică interactivă în timp real, folosind exclusiv limbajul de descriere hardware **Verilog**. 

Sistemul este construit de la zero la nivel de porți logice și circuite digitale, fără a folosi un microprocesor, un sistem de operare sau librării grafice externe. Proiectul este organizat curat pe GitHub pentru portofoliu și CV, având ca scop principal stăpânirea limbajului Verilog.

---

## 2. De Ce Am Ales Această Abordare și Placa Basys 3
1. **Specificul plăcii Basys 3 pentru grafică:** Placa este ideală pentru acest proiect deoarece dispune pe portul VGA de un convertor digital-analog (DAC) format din rețele de rezistoare, oferind 4 biți pentru fiecare canal (Roșu, Verde, Albastru). Acest setup RGB 4-4-4 permite afișarea a 4096 de culori distincte. În plus, placa oferă periferice fizice perfecte pentru control: 5 butoane dispuse tip D-Pad pentru deplasare pe ecran, 16 switch-uri și un afișaj cu 7 segmente pentru debugging fără a încărca monitorul.
2. **Dezvoltarea modulară (pe etape):** Proiectarea unui driver video necesită timpi stricți de sincronizare. Am ales să spargem proiectul în module independente (ceas, sincronizare video, logică grafică, memorie) pentru a putea simula, testa și izola eventualele erori de timing înainte de integrarea pe siliciu.

---

## 3. Pasi de Dezvoltare și Etapele de Implementare

### Etapa 1 (Săptămâna 1): Prime Succes - Driver-ul VGA și Validarea Sincronizării
**Scopul etapei:** Definirea succesului prin realizarea conexiunii dintre FPGA și monitor și obținerea unui semnal video stabil, conform standardului VESA 640x480 la 60 Hz.

* **Cum facem și detalii tehnice:**
  * **Divizorul de ceas:** Oscilatorul plăcii Basys 3 funcționează la o frecvență fixă de 100 MHz. Standardul VGA 640x480 @ 60 Hz cere o frecvență de pixeli de aproximativ 25 MHz (25.175 MHz). Implementăm un divizor de frecvență prin 4 (sau utilizăm Clocking Wizard în Vivado) pentru a obține ceasul de lucru `pixel_clk`.
  * **Modulul de sincronizare (`vga_sync`):** Construim două numărătoare: unul pentru baleiajul orizontal (0 - 799 pixeli) și unul pentru cel vertical (0 - 524 linii). Modulul generează impulsurile de sincronizare `Hsync` și `Vsync`, precum și semnalul logic `video_on`, care este activ doar în zona vizibilă a ecranului (640x480).
  * **Fișierul de constrângeri (`.xdc`):** Conectăm semnalele din Verilog (`vgaRed`, `vgaGreen`, `vgaBlue`, `Hsync`, `Vsync`, `clk`) la pinii fizici ai mufei VGA de pe placă.
* **Validarea succesului:** Atunci când trimitem o culoare constantă (ex: roșu maxim `4'b1111`) pe semnalul de ieșire, condiționat de `video_on`, întregul ecran al monitorului devine roșu curat, fără pâlpâiri.
* **Probleme întâmpinate și cum le-am rezolvat:**
  * *Problema:* Monitorul afișa mesajul "Out of Range" sau imaginea era descentrată pe orizontală.
  * *Rezolvarea:* Am utilizat Vivado Simulator (RTL Analysis) pentru a inspecta formele de undă generate de numărătoare și am ajustat timpii de Front Porch, Sync Pulse și Back Porch exact după specificațiile standardului VESA.

---

### Etapa 2 (Săptămâna 2): Optimizarea Codului și Adăugarea de Funcționalități
**Scopul etapei:** Revizuirea și refactorizarea codului Verilog pentru bune practici de scriere (clean code), urmată de implementarea primelor elemente grafice dinamice.

* **Cum facem și detalii tehnice:**
  * **Controller-ul de afișare (`display_controller.v`):** Decuplăm logica generării culorilor de modulul de sincronizare. Controller-ul evaluează coordonatele `(pixel_x, pixel_y)` la fiecare ciclu de ceas.
  * **Generarea formelor geometrice:** Definim zone carteziene pe ecran pentru a desena un obiect geometric (un pătrat / sprite). Când fasciculul trece prin interiorul coordonatelor obiectului, semnalul RGB preia culoarea formei; în rest, preia culoarea de fundal.
  * **Interfațarea butoanelor:** Conectăm butoanele fizice ale plăcii Basys 3 pentru a modifica variabilele de poziție `X` și `Y` ale obiectului, transformându-l într-un element controlabil (stânga, dreapta, sus, jos). Switch-urile modifică dinamic paleta de culori.
* **Probleme întâmpinate și cum le-am rezolvat:**
  * *Problema:* Când obiectul era mutat de din butoane, apăreau deformări vizuale, margini tăiate sau efect de ghosting pe monitor.
  * *Rezolvarea:* Am condiționat actualizarea coordonatelor matematice ale obiectului să se execute strict pe frontul semnalului `Vsync` (în perioada de Vertical Blanking), asigurând recalcularea traiectoriei doar atunci când tunul de scanare nu desenează activ pe ecran.

---

### Etapa 3 (Săptămâna 3): Creativitate și Complexitate Hardware
**Scopul etapei:** Transformarea proiectului de bază într-o lucrare complexă, potrivită pentru portofoliul tehnic și prezentarea finală, prin adăugarea unui motor de fizică sau a unor elemente de joc (Flappy Bird / Minesweeper / Particle Engine).

* **Cum facem și detalii tehnice:**
  * **Motorul de fizică (`particle_engine.v`):** Evoluăm de la o simplă formă statică la un sistem cu particule în mișcare continuă, afectate de gravitație și coliziuni cu marginile ecranului. Calculul cinematic ($V = V_0 + at$) și ricoșeul se implementează în hardware folosind aritmetică în virgulă fixă.
  * **Exploatarea memoriei interne (BRAM):** Pentru a gestiona simultan zeci de elemente pe ecran fără a epuiza porțile logice ale cipului Artix-7, stocăm coordonatele și stările particulelor în memoriile statice integrate (Block RAM).
  * **Extensie hardware (Opțional):** Conectăm un senzor extern (accelerometru MPU6050 sau senzor ultrasonic) la pinii Pmod pentru a controla fizica din joc prin gesturi sau prin înclinarea fizică a plăcii.
* **Probleme întâmpinate și cum le-am rezolvat:**
  * *Problema:* Concurența la memorie – modulul video încerca să citească din RAM culoarea pixelului în același timp în care motorul de fizică calcula noua poziție, generând erori grafice.
  * *Rezolvarea:* Am configurat memoria ca Block RAM Dual-Port, alocând un port exclusiv pentru citirea video (simultană cu scanarea monitorului) și celălalt port exclusiv pentru scrierea și actualizarea fizicii.

---

## 4. Setup și Organizare pe GitHub (SE POATE MODIFICA)
Pentru a păstra un repository curat, standardizat pentru mediul industrial și ușor de atașat la CV, proiectul exclude folderele temporare generate de Vivado (`.runs`, `.cache`, `.sim`, `.hw`) și păstrează doar structura de surse:

```text
Proiect-Capgemini/
│
├── Proiect/
│   ├── Proiect.xpr                  # Fișierul principal de proiect Vivado
│   │
│   ├── .srcs/
│   │   ├── sources_1/new/
│   │   │   ├── top_module.v         # Modulul principal de interfațare (Top Level)
│   │   │   ├── vga_sync.v           # Generatorul semnalelor Hsync, Vsync și video_on
│   │   │   ├── display_controller.v # Multiplexorul de grafică și culori
│   │   │   └── particle_engine.v    # Motorul matematic și logica de control
│   │   │
│   │   └── constrs_1/new/
│   │       └── basys3.xdc           # Maparea pinilor fizici I/O pe placa Basys 3
│   │
│   └── .gitignore                   # Filtru pentru excluderea fișierelor temporare
│
└── README.md                        # Documentația tehnică a proiectului