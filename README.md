# NativeStream ASM

Prototipo nativo, leggero e diretto, scritto in assembly x86_64 Linux senza runtime, senza traduttore e senza librerie esterne.

## Linux build

```bash
make
./main
```

## Android target

Il progetto include anche un target ARM64/Linux pronto per Android, con una build condizionale al toolchain aarch64:

```bash
make android
```

Se il cross-toolchain non è installato, il comando stampa un messaggio chiaro invece di fallire silenziosamente.

## Flusso app

- Host: inserisce fino a 3 path di eseguibili e salva la configurazione
- Client: legge i path salvati e permette la selezione
- Menu iniziale supporta anche il passaggio diretto con `--host` e `--client`

## Obiettivo

Il programma dimostra un flusso minimo di startup, configurazione host/client e selezione di eseguibili, usando solo syscall native del sistema operativo.
