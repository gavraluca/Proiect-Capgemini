# Documentație Tehnică de Proiect: Motor Grafic Hardware cu Interfațare de Senzori și Fizică în Timp Real (HPE-RT)

## 1. Descrierea Generală și Obiectivul Lucrării
**Hardware Particle Engine with Real-Time Interfacing (HPE-RT)** este un sistem digital embedded avansat, implementat pe un circuit integrat programabil de tip FPGA (Field-Programmable Gate Array). Proiectul are ca scop generarea, calculul cinematic și randarea video în timp real a unui sistem 2D de particule dinamice, a cărui traiectorie și accelerație sunt controlate activ de fenomene fizice externe citite prin intermediul unui **senzor extern conectat la porturile Pmod**.

Spre deosebire de o implementare software clasică, unde instrucțiunile sunt executate secvențial de un microprocesor, acest proiect realizează achiziția de date de la senzor, calculul fizic pe zeci/sute de obiecte, gestionarea memoriei RAM video și sincronizarea monitorului **complet în paralel, la nivel de logică digitală pură**, utilizând limbajul de descriere hardware **Verilog HDL**.

---

## 2. Specificații Tehnice și Mediu de Dezvoltare

* **Platformă Hardware Principală:** AMD / Xilinx Basys 3
* **Cip FPGA:** Artix-7 (Cod componentă: `XC7A35TCPG236-1`)
* **Frecvență de Ceas Sistem:** **100 MHz** (oscilator intern pe placă)
* **Interfață Video Output:** Port VGA 12-biți (4 biți/canal R, G, B), rezoluție standard **640x480** la o rată de reîmprospătare de **60 Hz**
* **Componentă Hardware Externă:** Accelerometru/Giroscop digital (ex. **MPU6050** sau **ADXL345**) conectat prin interfața Pmod pentru controlul vectorului gravitațional, sau Senzor Ultrasonic (**HC-SR04**) pentru generarea de câmpuri de repingere
* **Mediu de Proiectare și Sinteză (IDE):** Xilinx Vivado Design Suite
* **Protocoale de Comunicație Implementate:** I2C / SPI / UART (pentru senzorul extern), standard semnalizare VGA
* **Blocuri IP Xilinx Utilizate:** Clocking Wizard (MMCM/PLL), Block Memory Generator (BRAM)

---

## 3. Arhitectura Sistemului și Ierarhia Modulelor

Sistemul este proiectat pe o arhitectură modulară decuplată, coordonată de un modul structural de nivel înalt (`top_module.v`). Această abordare elimină blocajele de acces la memorie și permite procesarea paralelă a cadrelor video și a datelor de la senzor.
