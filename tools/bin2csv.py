# -*- coding: utf-8 -*-
"""
A tool for converting proprietary .BIN sensor data files to structured .CSV files.
(Sequential processing version with individual file progress)
"""
import argparse
import binascii
import csv
import io
import os
import struct
import sys
import time
from typing import Dict, List, Optional, Tuple, Callable

# You must install this library: pip install tqdm
from tqdm import tqdm

# --- Constants ---
# (Constants are the same as before)
FILE_HEADER_SIGNATURE = b'MDTC'
PACKET_HEADER_SIGNATURE = b'MDTCPACK'
REMARKS_SIZE = 512
CSV_HEADERS = [
    'dateTime', 'acc_x', 'acc_y', 'acc_z', 'gyr_x', 'gyr_y', 'gyr_z',
    'bodySurface_temp', 'ambient_temp', 'hr_raw', 'hr', 'remarks'
]
REMARKS_STRUCT = struct.Struct(f'<{REMARKS_SIZE}s')
FILE_HEADER_STRUCT = struct.Struct('<4sIHH')
PACKET_HEADER_STRUCT = struct.Struct('<8sIIIIIII')
ACC_GYRO_STRUCT = struct.Struct('<hhh')
TEMP_HEART_STRUCT = struct.Struct('<hh')

# --- Core Logic Functions ---

def _calculate_sensor_value(value: int, sensor_range: int) -> float:
    """Calculates the scaled value for an accelerometer or gyroscope reading."""
    if value == 0:
        return 0.0
    denominator = 32767 if value > 0 else 32768
    return value * sensor_range / denominator

def convert_bin_to_csv(bin_path: str, output_path: Optional[str] = None, 
                       progress_callback: Optional[Callable[[str, int, int], None]] = None) -> int:
    """
    Reads a proprietary binary file (.BIN), parses its contents, and writes
    the data to a structured CSV file.

    Args:
        bin_path: Path to the binary file to convert
        output_path: Path to output the CSV file (defaults to same name/location with .csv extension)
        progress_callback: Optional callback function to report progress (filename, current, total)

    Returns:
        The number of packets successfully processed.
    """
    if not os.path.exists(bin_path):
        raise FileNotFoundError(f"Input file not found at '{bin_path}'")

    if output_path is None:
        output_path = os.path.splitext(bin_path)[0] + '.csv'

    try:
        with open(bin_path, 'rb') as f_bin:
            data_stream = io.BytesIO(f_bin.read())
    except IOError as e:
        raise IOError(f"Error reading file '{bin_path}': {e}")

    remarks_bytes = data_stream.read(REMARKS_STRUCT.size)
    if len(remarks_bytes) < REMARKS_STRUCT.size:
        raise ValueError("File is too small to contain remarks.")
    remarks_tuple = REMARKS_STRUCT.unpack(remarks_bytes)
    remarks_string = remarks_tuple[0].decode('utf-8', 'ignore').split('\0', 1)[0]

    header_bytes = data_stream.read(FILE_HEADER_STRUCT.size)
    if len(header_bytes) < FILE_HEADER_STRUCT.size:
        raise ValueError("File is too small to contain a valid header.")

    try:
        signature, packet_count, acc_range, gyro_range = FILE_HEADER_STRUCT.unpack(header_bytes)
    except struct.error:
        raise ValueError("Could not unpack file header. The file may be corrupt.")

    if signature != FILE_HEADER_SIGNATURE:
        raise ValueError(f"Invalid file signature. Expected {FILE_HEADER_SIGNATURE!r}, got {signature!r}.")

    packet_data_buffer = data_stream.read()
    data_stream.close()

    last_timestamp = 0
    processed_packets_count = 0

    with open(output_path, 'w', newline='', encoding='utf-8-sig') as f_csv:
        writer = csv.DictWriter(f_csv, fieldnames=CSV_HEADERS)
        writer.writeheader()

        for packet_index in range(packet_count):
            # Report progress periodically
            if progress_callback and packet_index % 10 == 0:  # Report every 10 packets
                progress_callback(os.path.basename(bin_path), packet_index, packet_count)
                
            start_index = packet_data_buffer.find(PACKET_HEADER_SIGNATURE)
            if start_index == -1:
                break
            
            if start_index > 0:
                packet_data_buffer = packet_data_buffer[start_index:]

            end_index = packet_data_buffer.find(PACKET_HEADER_SIGNATURE, 1)

            if end_index == -1:
                current_packet_data = packet_data_buffer
                packet_data_buffer = b''
            else:
                current_packet_data = packet_data_buffer[:end_index]
                packet_data_buffer = packet_data_buffer[end_index:]

            if len(current_packet_data) < PACKET_HEADER_STRUCT.size:
                continue

            try:
                (
                    _, crc32, start_ts, end_ts,
                    acc_count, gyro_count, temp_count, heart_count
                ) = PACKET_HEADER_STRUCT.unpack_from(current_packet_data)
            except struct.error:
                continue
            
            payload_for_crc = current_packet_data[12:]
            calculated_crc32 = binascii.crc32(payload_for_crc)
            if calculated_crc32 != crc32:
                continue

            payload_offset = PACKET_HEADER_STRUCT.size
            sensor_data = current_packet_data[payload_offset:]
            max_count = max(acc_count, gyro_count, temp_count, heart_count)
            if max_count <= 0:
                continue

            if last_timestamp != 0 and (start_ts - last_timestamp >= 1):
                start_ts -= 1
            last_timestamp = end_ts
            time_step_ms = ((end_ts - start_ts) * 1000) / max_count if max_count > 1 else 0

            rows_for_packet: List[Dict] = [{'dateTime': int(start_ts * 1000 + i * time_step_ms)} for i in range(max_count)]

            if processed_packets_count == 0 and rows_for_packet:
                rows_for_packet[0]['remarks'] = remarks_string

            acc_end = acc_count * ACC_GYRO_STRUCT.size
            gyro_end = acc_end + gyro_count * ACC_GYRO_STRUCT.size
            temp_end = gyro_end + temp_count * TEMP_HEART_STRUCT.size
            acc_data, gyro_data, temp_data, heart_data = (
                sensor_data[:acc_end], sensor_data[acc_end:gyro_end],
                sensor_data[gyro_end:temp_end], sensor_data[temp_end:]
            )

            for i in range(acc_count):
                idx = int(i * (max_count / acc_count)) if acc_count > 0 else 0
                if idx < len(rows_for_packet):
                    x, y, z = ACC_GYRO_STRUCT.unpack_from(acc_data, i * ACC_GYRO_STRUCT.size)
                    rows_for_packet[idx].update({'acc_x': f"{_calculate_sensor_value(x, acc_range):.8f}", 'acc_y': f"{_calculate_sensor_value(y, acc_range):.8f}", 'acc_z': f"{_calculate_sensor_value(z, acc_range):.8f}"})
            for i in range(gyro_count):
                idx = int(i * (max_count / gyro_count)) if gyro_count > 0 else 0
                if idx < len(rows_for_packet):
                    x, y, z = ACC_GYRO_STRUCT.unpack_from(gyro_data, i * ACC_GYRO_STRUCT.size)
                    rows_for_packet[idx].update({'gyr_x': f"{_calculate_sensor_value(x, gyro_range):.8f}",'gyr_y': f"{_calculate_sensor_value(y, gyro_range):.8f}",'gyr_z': f"{_calculate_sensor_value(z, gyro_range):.8f}"})
            for i in range(temp_count):
                idx = int(i * (max_count / temp_count)) if temp_count > 0 else 0
                if idx < len(rows_for_packet):
                    body, ambient = TEMP_HEART_STRUCT.unpack_from(temp_data, i * TEMP_HEART_STRUCT.size)
                    rows_for_packet[idx].update({'bodySurface_temp': body / 10.0, 'ambient_temp': ambient / 10.0})
            for i in range(heart_count):
                idx = int(i * (max_count / heart_count)) if heart_count > 0 else 0
                if idx < len(rows_for_packet):
                    raw, hr = TEMP_HEART_STRUCT.unpack_from(heart_data, i * TEMP_HEART_STRUCT.size)
                    rows_for_packet[idx].update({'hr_raw': raw, 'hr': hr})

            writer.writerows(rows_for_packet)
            processed_packets_count += 1
            if not packet_data_buffer:
                break
    
    # Final progress update
    if progress_callback:
        progress_callback(os.path.basename(bin_path), packet_count, packet_count)
        
    return processed_packets_count

# --- PROCESSING FUNCTION ---

def process_file(source_file, source_base_dir, dest_base_dir):
    """Process a single file and display progress."""
    try:
        # Calculate the destination path
        rel_path = os.path.relpath(source_file, source_base_dir)
        dest_file = os.path.join(dest_base_dir, rel_path)
        dest_file = os.path.splitext(dest_file)[0] + '.csv'
        
        filename = os.path.basename(source_file)
        
        # Check if destination file already exists
        if os.path.exists(dest_file):
            # Check if file size is less than 400MB
            file_size = os.path.getsize(dest_file)
            if file_size >= 400 * 1024 * 1024:  # 400MB in bytes
                print(f"{filename}: Skipped (already converted)")
                return True, "Skipped (already converted)"
        
        # Create destination directory if needed
        os.makedirs(os.path.dirname(dest_file), exist_ok=True)
        
        # Setup progress display
        print(f"Converting: {filename}")
        
        # Proceed with conversion with progress reporting
        def progress_callback(fname, current, total):
            if total > 0:
                percentage = (current / total) * 100
                bar_length = 40
                filled_length = int(bar_length * current // total)
                bar = '█' * filled_length + '-' * (bar_length - filled_length)
                # Clear line and rewrite progress
                print(f"\r{filename[:30]:30} [{bar}] {percentage:.1f}%", end='')
        
        # Process the file
        convert_bin_to_csv(source_file, dest_file, progress_callback)
        print()  # New line after progress bar
        
        return True, "Success"
    except Exception as e:
        print(f"\nERROR processing {os.path.basename(source_file)}: {str(e)}")
        return False, str(e)


# --- MAIN EXECUTION BLOCK ---

if __name__ == "__main__":
    # EDIT per machine
    source_base_dir = r"F:\PMP_T1"
    dest_base_dir = r"C:\path\to\PMP_T1"
    
    if not os.path.exists(dest_base_dir):
        os.makedirs(dest_base_dir)
    
    print(f"Scanning {source_base_dir} for .bin files...")
    
    files_to_process = []
    for root, _, files in os.walk(source_base_dir):
        for f in files:
            if f.lower().endswith('.bin'):
                files_to_process.append(os.path.join(root, f))

    if not files_to_process:
        print("No .bin files found to process.")
        sys.exit(0)

    print(f"Found {len(files_to_process)} .bin files. Starting sequential conversion...")
    
    success_count = 0
    failure_count = 0
    skipped_count = 0
    failed_files = []  # Track failed files with their errors
    
    # Process files one by one
    for i, file_path in enumerate(files_to_process, 1):
        print(f"\nFile {i} of {len(files_to_process)}")
        success, message = process_file(file_path, source_base_dir, dest_base_dir)
        
        if success:
            if message == "Skipped (already converted)":
                skipped_count += 1
            else:
                success_count += 1
        else:
            failure_count += 1
            failed_files.append((file_path, message))

    print("\n--- All conversions attempted. ---")
    print(f"Successfully converted: {success_count}")
    print(f"Already converted (skipped): {skipped_count}")
    print(f"Failed conversions: {failure_count}")
    
    # Display specific failed files
    if failed_files:
        print("\n--- FAILED FILES ---")
        for file_path, error_msg in failed_files:
            print(f"FAILED: {os.path.basename(file_path)}")
            print(f"  Path: {file_path}")
            print(f"  Error: {error_msg}")
            print()