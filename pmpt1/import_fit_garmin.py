import csv
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    from fitparse import FitFile
except ModuleNotFoundError as exc:
    raise SystemExit(
        "Falta el paquete 'fitparse'. Instalar con: python -m pip install fitparse"
    ) from exc


# ============================================================
# Configuracion
# ============================================================

BASE_DIR = Path(__file__).resolve().parent
NAS_DIR = Path(r"\\smb2.i3a.es\nas2\bsicos01\__comun\ecg\PMP_T1\PMP_T1_rawfiles")
OUTPUT_DIR = BASE_DIR / "data_fit"

try:
    TIMEZONE_LOCAL = ZoneInfo("Europe/Madrid")
except ZoneInfoNotFoundError as exc:
    raise SystemExit(
        "No se encuentra la zona horaria 'Europe/Madrid'. "
        "Instalar con: python -m pip install tzdata"
    ) from exc


def to_utc(timestamp):
    if not isinstance(timestamp, datetime):
        raise TypeError(f"Timestamp FIT no reconocido: {timestamp!r}")

    if timestamp.tzinfo is None:
        return timestamp.replace(tzinfo=timezone.utc)

    return timestamp.astimezone(timezone.utc)


def process_fit_file(fit_path, output_dir):
    output_csv = output_dir / (fit_path.stem + "_FC.csv")

    fitfile = FitFile(str(fit_path))
    records = []
    available_fields = set()

    for message in fitfile.get_messages("record"):
        row = {field.name: field.value for field in message}
        available_fields.update(row)

        if "timestamp" not in row or "heart_rate" not in row:
            continue

        if row["timestamp"] is None or row["heart_rate"] is None:
            continue

        timestamp_utc = to_utc(row["timestamp"])
        records.append(
            {
                "timestamp_utc": timestamp_utc,
                "timestamp_local": timestamp_utc.astimezone(TIMEZONE_LOCAL),
                "heart_rate": float(row["heart_rate"]),
            }
        )

    if not records:
        if not available_fields:
            raise ValueError("No se han encontrado mensajes de tipo 'record' en el archivo FIT.")

        if "timestamp" not in available_fields:
            raise ValueError("El archivo FIT no contiene campo 'timestamp'.")

        if "heart_rate" not in available_fields:
            raise ValueError(
                "El archivo FIT no contiene el campo 'heart_rate'. "
                f"Campos disponibles: {sorted(available_fields)}"
            )

        raise ValueError("No hay registros con frecuencia cardiaca valida.")

    t0 = records[0]["timestamp_utc"]

    for record in records:
        elapsed_seconds = (record["timestamp_utc"] - t0).total_seconds()
        record["elapsed_seconds"] = elapsed_seconds
        record["elapsed_minutes"] = elapsed_seconds / 60.0

    with output_csv.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=[
                "timestamp_utc",
                "timestamp_local",
                "elapsed_seconds",
                "elapsed_minutes",
                "heart_rate",
            ],
        )
        writer.writeheader()

        for record in records:
            writer.writerow(
                {
                    "timestamp_utc": record["timestamp_utc"].isoformat(),
                    "timestamp_local": record["timestamp_local"].isoformat(),
                    "elapsed_seconds": record["elapsed_seconds"],
                    "elapsed_minutes": record["elapsed_minutes"],
                    "heart_rate": record["heart_rate"],
                }
            )

    heart_rate = [record["heart_rate"] for record in records]

    return {
        "fit_path": fit_path,
        "output_csv": output_csv,
        "n_records": len(records),
        "start_utc": records[0]["timestamp_utc"],
        "end_utc": records[-1]["timestamp_utc"],
        "start_local": records[0]["timestamp_local"],
        "end_local": records[-1]["timestamp_local"],
        "min_hr": min(heart_rate),
        "max_hr": max(heart_rate),
        "mean_hr": sum(heart_rate) / len(heart_rate),
    }


def find_fit_files(nas_dir):
    if not nas_dir.exists():
        raise FileNotFoundError(f"No se puede acceder al NAS: {nas_dir}")

    fit_files = []
    for subject_dir in sorted(nas_dir.iterdir()):
        if not subject_dir.is_dir():
            continue
        fit_files.extend(sorted(subject_dir.glob("*.fit")))
        fit_files.extend(sorted(subject_dir.glob("*.FIT")))

    return fit_files


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    fit_files = find_fit_files(NAS_DIR)

    if not fit_files:
        raise FileNotFoundError(f"No se han encontrado archivos .fit en: {NAS_DIR}")

    print(f"NAS:    {NAS_DIR}")
    print(f"Salida: {OUTPUT_DIR}")
    print(f"Archivos .fit encontrados: {len(fit_files)}")
    print()

    processed = []
    failed = []

    for fit_path in fit_files:
        print(f"Procesando: {fit_path.parent.name}/{fit_path.name}")
        try:
            summary = process_fit_file(fit_path, OUTPUT_DIR)
        except Exception as exc:
            print(f"  ERROR: {exc}")
            failed.append((fit_path, exc))
            print()
            continue

        processed.append(summary)
        print(f"  CSV: {summary['output_csv'].name}")
        print(f"  Registros con FC valida: {summary['n_records']}")
        print(f"  Inicio local: {summary['start_local']}")
        print(f"  Fin local:    {summary['end_local']}")
        print(
            "  FC min/max/media: "
            f"{summary['min_hr']:.1f} / {summary['max_hr']:.1f} / {summary['mean_hr']:.1f} bpm"
        )
        print()

    print(f"Importacion completada: {len(processed)} archivo(s) procesado(s).")
    if failed:
        print(f"Errores: {len(failed)} archivo(s).")
        for fit_path, exc in failed:
            print(f"  - {fit_path.parent.name}/{fit_path.name}: {exc}")


if __name__ == "__main__":
    main()
