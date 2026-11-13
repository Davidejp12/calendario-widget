# Calendario Widget

Widget per il desktop di macOS che mostra un calendario Notion: griglia del mese
a sinistra, prossimi eventi a destra. Sta incollato allo sfondo, sotto tutte le
finestre, e si aggiorna da Notion ogni 5 minuti. Niente da installare: è una
piccola app Swift (AppKit + WebKit) con la grafica in un file HTML.

- Trascina dalla barra del titolo per spostarlo, dall'angolo in basso a destra per ridimensionarlo
- `‹ • ›` cambiano mese / tornano a oggi
- `+` oppure clic su un giorno → nuovo evento (tutto il giorno o con orario), salvato su Notion
- `⚙︎` → colore (6 temi), trasparenza, grandezza Piccolo / Medio / Grande
- Clic su un evento → apre la pagina in Notion
- In alto: `Notion · data` = aggiornato, `copia locale` = senza token, `offline` = Notion non risponde

Requisiti: macOS 13+ e gli strumenti da riga di comando di Xcode (`xcode-select --install`).

## Installazione

1. **Compila**
   ```sh
   git clone https://github.com/Davidejp12/calendario-widget.git
   cd calendario-widget
   ./build.sh
   ```

2. **Il database Notion** deve avere una proprietà titolo `Name` e una proprietà data `Date`
   (è la struttura della vista *Calendario* di Notion).

3. **Crea un'integrazione** su [notion.so/my-integrations](https://www.notion.so/my-integrations):
   tipo *Interna*, con i permessi *Read content* e *Insert content*. Copia il
   *Internal Integration Secret*.

4. **Collega l'integrazione** alla pagina che contiene il calendario: `•••` → *Connessioni* → aggiungila.

5. **Configura** — due file nella cartella del progetto, entrambi esclusi da git:
   ```sh
   echo "IL_TUO_TOKEN" > token.txt
   echo "LINK_O_ID_DEL_DATABASE" > database_id.txt
   ```
   Per `database_id.txt` va bene il link del database copiato da Notion (*Copia link*) o il solo ID di 32 caratteri.

6. **Avvia**
   ```sh
   open "Calendario Widget.app"
   ```

## Comandi

| Cosa | Comando |
|---|---|
| Aprire | `open "Calendario Widget.app"` |
| Chiudere | `pkill Calendario` |
| Riavviare | `pkill Calendario; open "Calendario Widget.app"` |
| È acceso? | `pgrep -l Calendario` |
| Ricompilare dopo una modifica | `./build.sh` |
| Ultimo aggiornamento | `python3 -c "import json;d=json.load(open('cache.json'));print(d['source'],d['updated'],len(d['events']),'eventi')"` |

Per rigenerare l'icona dopo aver modificato `icona.swift`, cancella
`Calendario Widget.app/Contents/Resources/Calendario.icns` e lancia `./build.sh`.

**Avvio automatico:** *Impostazioni di Sistema → Generali → Elementi login → +* → `Calendario Widget.app`.

## File

| File | Cosa fa |
|---|---|
| `Calendario.swift` | finestra sul desktop, lettura e scrittura su Notion |
| `widget.html` | grafica del calendario, temi, modulo nuovo evento |
| `icona.swift` | disegna l'icona dell'app |
| `build.sh` | compila app e icona |
| `token.txt` | token dell'integrazione Notion — *locale, non su git* |
| `database_id.txt` | quale database leggere — *locale, non su git* |
| `cache.json` | ultima copia degli eventi, usata anche offline — *locale* |
| `settings.json` | colore e trasparenza scelti — *locale* |

Se compare `offline`, di solito l'integrazione non è collegata alla pagina del
database. Se il salvataggio di un evento dà errore, attiva *Insert content*
nelle impostazioni dell'integrazione.

## Licenza

[MIT](LICENSE)
