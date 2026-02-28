import socket
import threading
import time
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path
import zlib

SERVER_HOST = '0.0.0.0'
FILE_SAVE_DIR = "./files_root_dir"
TEMP_FILE_SUFFIX = ".jpart"
MAX_CONNECTIONS = 10

UE_UPLOAD_PORT = 6666
UE_UPLOAD_BLOCK_SIZE = 1024
UE_TIMEOUT = 60
UE_DOWNLOAD_PORT = 7777
ERROR_CODE_DIC = {
    "ERROR1":'FILE DIC ERROR',
    "ERROR2":'ALREADY COMPLETE',
    "ERROR3":'CRC ERROR',
    "ERROR4":'MD5 ERROR',
    "ERROR5":'JSON PARSE ERROR',
    "ERROR6":'UPLOADING...',
    "ERROR7":'FILE NOT EXIST',
    "ERROR8":'ERROR ROOT DIR',

    "ERRORO":'OTHER ERROR',

    "OK":'',
    "FINISH":'',
}
download_process_dic = {}
LOGIN_DIC = {}
Path(FILE_SAVE_DIR).mkdir(parents=True, exist_ok=True)
debug_ctl_flag = True

def caculate_crc32(data):
    if isinstance(data, str):
        data = data.encode('utf-8')
    crc32_value = zlib.crc32(data)
    return crc32_value & 0xFFFFFFFF

def caculate_md5(filepath):
    if not os.path.exists(filepath):
        return ""
    md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        while chunk:= f.read(8192):
            md5.update(chunk)
    return md5.hexdigest()

def send_stander_ack(_socket, prefix, req_type, status, message, offset=0):
    ack = {
        "req_type": req_type,
        "status": status,
        "message": message,
        "offset": offset,
    }
    ack_str = json.dumps(ack)
    crc = "%08X" % caculate_crc32(ack_str)
    s = "%04x" % (len(ack_str) + len(crc))
    ack_block = f"{prefix}{s}{ack_str}{crc}".encode("utf-8")
    print(ack_block)
    _socket.sendall(ack_block)

def send_data_block(_socket, idx, data):
    idxv = "%06X" % idx
    crcv = "%08X" % caculate_crc32(data)
    data_size = "%04X" % (len(data) + 6 + 8)
    data_block = "|SV>GD|DO:".encode("utf-8") + data_size.encode("utf-8") + idxv.encode("utf-8") + data + crcv.encode("utf-8")
    if idx % 100 == 0:
        print(data_block[:40])
    _socket.sendall(data_block)

def handle_login(login_socket, client_addr, meta_json):
    req_type = meta_json.get("req_type", "")
    usr = meta_json.get("usr", "")
    psd = meta_json.get("psd", "")
    if not (req_type and usr and psd):
        print("[%s]ue(%s)request login parameters missing" % (datetime.now(), client_addr))
        send_stander_ack(login_socket, "|SV>GD|RQ:", 'login', "ERROR1", ERROR_CODE_DIC["ERROR1"], 0)
        return False
    send_stander_ack(login_socket, "|SV>GD|RQ:", 'login', "OK", "", 0)
    LOGIN_DIC[client_addr] = {'usr': usr, 'socket': login_socket}
    usr_dir = os.path.join(FILE_SAVE_DIR, usr)
    if not os.path.exists(usr_dir):
        os.mkdir(usr_dir)
    LOGIN_DIC[client_addr]['usr_dir'] = usr_dir
    print('current LOGIN_DIC is :', LOGIN_DIC)
    return True

def update_login_dic(_socket, client_addr):
    if client_addr in LOGIN_DIC:
        del LOGIN_DIC[client_addr]
    print('current LOGIN_DIC is :', LOGIN_DIC)

######################### func1 upload #######################
def handle_ue_upload(upload_socket:socket.socket, client_addr:tuple):
    print("%s new client access:%s" % (datetime.now(), client_addr))
    upload_socket.settimeout(UE_TIMEOUT)
    upload_text = {
        "is_uploading": True,
        "filename":'',
        "gd_filepath":'',
        "tmp_file_path": '',
        "fin_file_path": '',
        "file_size": 0,
        "offset": 0,
        "file_md5": ""}
    try:
        while True:
            data_head = upload_socket.recv(10)
            if not data_head:
                print("[%s]ue(%s) upload close(no data)"%(datetime.now(), client_addr))
                break
            vidx = data_head.find(b'|GD>SV|RQ:')
            vidy = data_head.find(b'|GD>SV|DO:')
            #print("[%s]ue(%s) upload receive data:"%(datetime.now(), client_addr), data_head)
            #print('current LOGIN_DIC is :', LOGIN_DIC)
            if vidx >= 0:
                handle_ue_upload_req(upload_socket, client_addr, upload_text)
            elif vidy >= 0:
                r = handle_ue_upload_do(upload_socket, client_addr, upload_text)
                if not r:
                    break
            else:
                print("[%s]ue(%s) receive unknow data:%s"%(datetime.now(), client_addr, data_head))
    except Exception as e:
        import traceback
        print(traceback.format_exc())
    finally:
        upload_socket.close()
        update_login_dic(upload_socket, client_addr)
        print("[%s]ue(%s) upload link disconnect"%(datetime.now(), client_addr))

def handle_ue_upload_req(upload_socket:socket.socket, client_addr:tuple, upload_text):
    try:
        req_len = upload_socket.recv(4)
        if not req_len:
            print("[%s]ue(%s) request upload close(no data1)"%(datetime.now(), client_addr))
            return False
        data = upload_socket.recv(int(req_len, 16))
        if not data:
            print("[%s]ue(%s) request upload close(no data2)"%(datetime.now(), client_addr))
            return False
        meta_json = json.loads(data[:-8].decode("utf-8"))
        req_type = meta_json.get("req_type", "")
        if req_type == 'upload':
            handle_ue_upload_details(upload_socket, client_addr, meta_json, upload_text)
        elif req_type == 'query':
            handle_query(upload_socket, client_addr, meta_json)
        elif req_type == 'login':
            handle_login(upload_socket, client_addr, meta_json)
        else:
            print("[%s]ue(%s) upload receive invalid data type:%s"%(datetime.now(), client_addr, req_type))
    except Exception as e:
        import traceback
        print(traceback.format_exc())

def handle_query(upload_socket:socket.socket, client_addr:tuple, meta_json:dict):
    req_type = meta_json.get("req_type", "")
    filedic = meta_json.get("filedic", "")
    if not (req_type and filedic):
        print("[%s]ue(%s) query data missing"%(datetime.now(), client_addr))
        send_stander_ack(upload_socket, "|SV>GD|RQ:", "upload", "ERROR1", ERROR_CODE_DIC["ERROR1"], 0)
        return False
    rt = []
    file_dic = json.loads(filedic)
    for filepath, md5 in file_dic.items():
        usr_dir = LOGIN_DIC[client_addr]['usr_dir']
        fin_file_path = os.path.join(usr_dir, filepath)
        md5_check = caculate_md5(fin_file_path)
        if md5_check != md5:
            rt.append(filepath)
    if rt == []:
        rt = ['all ok']
    send_stander_ack(upload_socket, "|SV>GD|RQ:", 'query', "OK", ";".join(rt), 0)
    return True

def handle_ue_upload_details(upload_socket:socket.socket, client_addr:tuple, meta_json, upload_text):
    req_type = meta_json.get("req_type", "")
    filepath = meta_json.get("filepath", "")
    file_size = meta_json.get("file_size", 0)
    file_md5 = meta_json.get("file_md5", "")
    overwrite = meta_json.get("overwrite", '')
    if not (overwrite and req_type and filepath and file_md5 and file_size > 0):
        print("[%s]ue(%s) request upload parameters missing"%(datetime.now(), client_addr))
        send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR1", ERROR_CODE_DIC["ERROR1"], 0)
        return False
    print("[%s]ue(%s) request upload parameters OK: filepath is %s, filesize is %s, md5 is %s"%(datetime.now(), client_addr, filepath, file_size, file_md5))
    upload_text['gd_filepath'] = filepath
    usr_dir = LOGIN_DIC.get(client_addr, {}).get("usr_dir", "")
    if not usr_dir:
        print("[%s]ue(%s) upload root dir mistake"%(datetime.now(), client_addr))
        send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR8", ERROR_CODE_DIC["ERROR8"], 0)
        return False
    filename = os.path.basename(filepath)
    _filedir = os.path.dirname(filepath)
    if _filedir == '\\':
        filedir = usr_dir
    else:
        filedir = os.path.join(usr_dir, _filedir)
    os.makedirs(filedir, exist_ok=True)
    tmp_file_name = f"{filename}_{file_md5}{TEMP_FILE_SUFFIX}"
    temp_file_path = os.path.join(filedir, tmp_file_name)
    fin_file_path = os.path.join(filedir, filename)
    sv_offset = 0
    if os.path.exists(fin_file_path):
        md5_check = caculate_md5(fin_file_path)
        if md5_check == file_md5:
            if overwrite == 'yes':
                os.remove(fin_file_path)
            else:
                send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR2", ERROR_CODE_DIC["ERROR2"], 0)
                return False
        else:
            os.remove(fin_file_path)

    if os.path.exists(temp_file_path):
        if overwrite == 'yes':
            os.remove(temp_file_path)
        else:
            sv_offset = os.path.getsize(temp_file_path)
            if sv_offset >= file_size:
                os.remove(temp_file_path)
                sv_offset = 0
    print("[%s]ue(%s) request upload, server offset is: %s"%(datetime.now(), client_addr, sv_offset))

    upload_text['is_uploading'] = True
    upload_text['tmp_file_path'] = temp_file_path
    upload_text['filename'] = filename
    upload_text['fin_file_path'] = fin_file_path
    upload_text['file_size'] = file_size
    upload_text['offset'] = sv_offset
    upload_text['file_md5'] = file_md5
    send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', 'OK', '', sv_offset)
    return True

def handle_ue_upload_do(upload_socket:socket.socket, client_addr:tuple, upload_text):
    global debug_ctl_flag
    try:
        req_len = upload_socket.recv(4)
        if not req_len:
            print("[%s]ue(%s) upload close(no data3)"%(datetime.now(), client_addr))
            return False
        data = upload_socket.recv(int(req_len, 16))
        if not data:
            print("[%s]ue(%s) upload close(no data4)"%(datetime.now(), client_addr))
            return False
        idx = data[:6]
        data_block = data[6:-8]
        crc = int(data[-8:], 16)
        if not upload_text['is_uploading']:
            send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR6", ERROR_CODE_DIC["ERROR6"], 0)
            return False
        crc_check = caculate_crc32(data_block)
        if crc_check != crc:
            send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR7", ERROR_CODE_DIC["ERROR7"], 0)
            return False
        tmp_file_path = upload_text['tmp_file_path']
        sv_offset = upload_text['offset']
        file_size = upload_text['file_size']
        with open(tmp_file_path, 'ab') as f:
            f.write(data_block)
        new_offset = sv_offset + len(data_block)
        upload_text['offset'] = new_offset
        #if debug_ctl_flag and (new_offset / file_size) > 0.2:
        #    debug_ctl_flag = False
        #    send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR4", ERROR_CODE_DIC["ERROR4"], 0)
        #    return False
        if new_offset >= file_size:
            md5 = upload_text['file_md5']
            md5_check = caculate_md5(tmp_file_path)
            if md5_check != md5:
                send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERROR4", ERROR_CODE_DIC["ERROR4"], 0)
                return False
            fin_file_name = upload_text["fin_file_path"]
            os.rename(tmp_file_path, fin_file_name)
            send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "FINISH", "FINISH", 0)
            upload_text['is_uploading'] = False
            print("[%s]ue(%s) upload finish"%(datetime.now(), client_addr))
            upload_socket.close()
            update_login_dic(upload_socket, client_addr)
            print("[%s]ue(%s) upload link disconnect"%(datetime.now(), client_addr))
            return True
        else:
            global download_process_dic
            filepath = upload_text['fin_file_path']
            download_process = download_process_dic.get(filepath, '0.0')
            new_download_process = "%.1f"%(new_offset / file_size)
            if new_download_process != download_process:
                send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "PROCESS", "%s;%s" % (upload_text['gd_filepath'], file_size), new_offset)
                download_process_dic[filepath] = new_download_process
        return True
    except Exception as e:
        import traceback
        print(traceback.format_exc())
        send_stander_ack(upload_socket, "|SV>GD|RQ:", 'upload', "ERRORO", ERROR_CODE_DIC["ERRORO"], 0)
        return False

############################ ue download ###############################
def handle_ue_download(download_socket: socket.socket, client_addr: tuple):
    print("[%s]new ue(%s) access" % (datetime.now(), client_addr))
    download_socket.settimeout(UE_TIMEOUT)
    download_text = {}
    try:
        while True:
            data_head = download_socket.recv(10)
            if not data_head:
                print("[%s]ue(%s) request download close(no data)" % (datetime.now(), client_addr))
                break
            vidx = data_head.find(b'|GD>SV|RQ:')
            print("download----->", data_head)
            if vidx >= 0:
                handle_ue_download_req(download_socket, client_addr, download_text)
            else:
                print("[%s]ue(%s) request download receive unknow data:%s" % (datetime.now(), client_addr, data_head))
    except Exception as e:
        import traceback
        print(traceback.format_exc())
    finally:
        download_socket.close()
        update_login_dic(download_socket, client_addr)
        print("[%s]ue(%s) download link disconnect"%(datetime.now(), client_addr))

def handle_ue_download_req(download_socket:socket.socket, client_addr:tuple, download_text):
    req_type = ""
    try:
        req_len = download_socket.recv(4)
        if not req_len:
            print("[%s]ue(%s) request download close(no data1)"%(datetime.now(), client_addr))
            return False
        data = download_socket.recv(int(req_len, 16))
        if not data:
            print("[%s]ue(%s) request download close(no data2)"%(datetime.now(), client_addr))
            return False
        print("[%s]ue(%s) request download receive data: %s"%(datetime.now(), client_addr, data))
        meta_json = json.loads(data[:-8].decode("utf-8"))
        req_type = meta_json.get("req_type", "")
        if req_type == 'download':
            handle_ue_download_details(download_socket, client_addr, meta_json, download_text)
        elif req_type == 'login':
            handle_login(download_socket, client_addr, meta_json)
        else:
            print("[%s]ue(%s) download receive invalid data type:%s"%(datetime.now(), client_addr, req_type ))
    except Exception as e:
        import traceback
        print(traceback.format_exc())

def handle_ue_download_details(download_socket:socket.socket, client_addr:tuple, meta_json, download_text):
    req_type = meta_json.get("req_type", "")
    filepath = meta_json.get("filepath", "")
    offset = int(meta_json.get("offset", -1))
    status = meta_json.get("status", "")
    if not (status and req_type and filepath):
        print("[%s]ue(%s) request download parameters missing"%(datetime.now(), client_addr))
        send_stander_ack(download_socket, "|SV>GD|RQ:", 'download', "ERROR1", ERROR_CODE_DIC["ERROR1"], 0)
        return False
    print("[%s]ue(%s) request download parameters OK:%s"%(datetime.now(), client_addr, filepath))
    usr_dir = LOGIN_DIC.get(client_addr, {}).get("usr_dir", "")
    if not usr_dir:
        print("[%s]ue(%s) request download usr dir missing"%(datetime.now(), client_addr))
        send_stander_ack(download_socket, "|SV>GD|RQ:", 'download', "ERROR8", ERROR_CODE_DIC["ERROR8"], 0)
        return False
    fin_file_path = os.path.join(usr_dir, filepath)
    if status == "OK":
        if offset >= 0:
            time.sleep(0.5)
            print("[%s]ue(%s) request download, server will send data... ..." % (datetime.now(), client_addr))
            threading.Thread(target=handle_ue_download_do, args=(download_socket, fin_file_path, meta_json, download_text)).start()
            return True
        else:
            print("[%s]ue(%s) request download offset < 0" % (datetime.now(), client_addr))
            send_stander_ack(download_socket, "|SV>GD|RQ:", 'download', "ERROR1", ERROR_CODE_DIC["ERROR1"], 0)
            return False
    if not os.path.isfile(fin_file_path):
        send_stander_ack(download_socket, "|SV>GD|RQ:", 'download', "ERROR7", ERROR_CODE_DIC["ERROR7"], offset)
        return False
    md5_check = caculate_md5(fin_file_path)
    sv_file_size = os.stat(fin_file_path).st_size
    send_stander_ack(download_socket, "|SV>GD|RQ:", 'download', 'OK', '%s;%s'%(sv_file_size, md5_check), offset)
    return True

def handle_ue_download_do(download_socket:socket.socket, fin_file_path, meta_json, download_text):
    print("[%s]start handle ue download:%s"%(datetime.now(), fin_file_path))
    file_size = os.path.getsize(fin_file_path)
    offset = meta_json.get("offset", 0)
    idx = 0
    with open(fin_file_path, 'rb') as f:
        f.seek(offset)
        while True:
            data = f.read(UE_UPLOAD_BLOCK_SIZE)
            if not data:
                print("[%s]start handle ue download finish(data.size=0):%s" % (datetime.now(), fin_file_path))
                break
            send_data_block(download_socket, idx, data)
            idx += 1
            if offset * UE_UPLOAD_BLOCK_SIZE >= file_size:
                print("[%s]start handle ue download finish(size>=file_size):%s" % (datetime.now(), fin_file_path))
                break
    print("[%s]finish handle ue download:%s" % (datetime.now(), fin_file_path))

def start_godot_upload_server():
    godot_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    godot_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    godot_socket.bind((SERVER_HOST, UE_UPLOAD_PORT))
    godot_socket.listen(MAX_CONNECTIONS)
    print("[%s]ue upload server listen  %s:%s"%(datetime.now(), SERVER_HOST, UE_UPLOAD_PORT))
    while True:
        client_socket, addr = godot_socket.accept()
        print('======================================== new request =========================================')
        threading.Thread(target=handle_ue_upload, args=(client_socket, addr), daemon=True).start()


def start_godot_download_server():
    godot_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    godot_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    godot_socket.bind((SERVER_HOST, UE_DOWNLOAD_PORT))
    godot_socket.listen(MAX_CONNECTIONS)
    print("[%s]ue download server listen  %s:%s" % (datetime.now(), SERVER_HOST, UE_DOWNLOAD_PORT))
    while True:
        client_socket, addr = godot_socket.accept()
        print('======================================== new request =========================================')
        threading.Thread(target=handle_ue_download, args=(client_socket, addr), daemon=True).start()

if __name__ == "__main__":
    try:
        threading.Thread(target=start_godot_upload_server, daemon=True).start()
        threading.Thread(target=start_godot_download_server, daemon=True).start()
        while True:
            time.sleep(1)
    except:
        import traceback
        print(traceback.format_exc())

