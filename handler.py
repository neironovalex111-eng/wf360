import base64
import json
import os
import time
import urllib.request
import uuid

import requests

#
# runpod_handler.py
#
import runpod
import websocket

# --- КОНФИГУРАЦИЯ ---
# Адрес API ComfyUI внутри контейнера
COMFYUI_API_ADDRESS = "http://127.0.0.1:8188"
# Уникальный ID для нашей сессии
CLIENT_ID = str(uuid.uuid4())

def upload_image_from_url(image_url):
    """
    Скачивает изображение по URL и загружает его в ComfyUI через API.
    Возвращает имя файла, которое присвоил ComfyUI.
    """
    # Скачиваем картинку во временный файл
    filename = os.path.basename(image_url.split('?')[0]) # Простое получение имени файла
    urllib.request.urlretrieve(image_url, filename)

    # Готовим данные для POST-запроса (multipart/form-data)
    with open(filename, 'rb') as f:
        files = {'image': (filename, f, 'image/jpeg')} # Тип можно менять
        data = {'overwrite': 'true'} # Перезаписывать, если файл существует
        
        # Отправляем в ComfyUI
        try:
            response = requests.post(f"{COMFYUI_API_ADDRESS}/upload/image", files=files, data=data)
            response.raise_for_status()
            
            # Убираем за собой временный файл
            os.remove(filename)

            # Возвращаем имя файла, под которым его сохранил ComfyUI
            return response.json()['name']
        except requests.RequestException as e:
            print(f"Пиздец, не удалось загрузить картинку: {e}")
            return None


def upload_image_from_base64(base64_string):
    """
    Декодирует изображение из Base64 и загружает его в ComfyUI через API.
    Возвращает имя файла, которое присвоил ComfyUI.
    """
    try:
        # Декодируем строку Base64 в бинарные данные
        image_data = base64.b64decode(base64_string)

        # Готовим данные для POST-запроса (multipart/form-data)
        # Мы передаем бинарные данные прямо в память, без создания файла
        # ВАЖНО: Укажите правильный content-type (image/png, image/jpeg и т.д.)
        # Здесь мы для примера используем 'image.png'
        filename = "uploaded_image.png"
        files = {'image': (filename, image_data, 'image/png')} 
        data = {'overwrite': 'true'} # Перезаписывать, если файл существует

        # Отправляем в ComfyUI
        response = requests.post(f"{COMFYUI_API_ADDRESS}/upload/image", files=files, data=data)
        response.raise_for_status()

        # Возвращаем имя файла, под которым его сохранил ComfyUI
        return response.json()['name']
        
    except (requests.RequestException, base64.binascii.Error, KeyError) as e:
        print(f"Пиздец, не удалось загрузить картинку из Base64: {e}")
        return None

def queue_prompt(prompt_workflow):
    """Отправляет workflow в очередь ComfyUI API"""
    try:
        data = json.dumps({"prompt": prompt_workflow, "client_id": CLIENT_ID}).encode('utf-8')
        req = requests.post(f"{COMFYUI_API_ADDRESS}/prompt", data=data)
        req.raise_for_status()
        return req.json()
    except requests.RequestException as e:
        print(f"Пиздец, не удалось поставить в очередь: {e}")
        return None

def get_image_data(ws, prompt_id, output_node_id):
    """Слушает WebSocket и вытаскивает результат из нужной ноды"""
    while True:
        out = ws.recv()
        if isinstance(out, str):
            message = json.loads(out)
            if message['type'] == 'executing':
                data = message['data']
                # Если выполнение завершено для нашего prompt_id, выходим
                if data['node'] is None and data['prompt_id'] == prompt_id:
                    break
    
    # Забираем историю и находим результат по ID ноды
    try:
        history_res = requests.get(f"{COMFYUI_API_ADDRESS}/history/{prompt_id}").json()
        output_data = history_res[prompt_id]['outputs'][output_node_id]['images'][0]
        
        # Собираем полный URL для доступа к картинке
        image_url = f"{COMFYUI_API_ADDRESS}/view?filename={output_data['filename']}&subfolder={output_data['subfolder']}&type={output_data['type']}"
        
        return {"image_url": image_url}
    except Exception as e:
        print(f"Пиздец, не удалось получить результат: {e}")
        return {"error": "Не удалось извлечь результат из истории."}


def handler(job):
    """
    Основной обработчик, который дёргает RunPod.
    """
    job_input = job['input']
    print(job_input)
    image = job_input.get("image")

    if not image:
        return {"error": "Бро, ты забыл передать 'image_url' в запросе."}

    # 1. Загружаем картинку в ComfyUI. Это наш первый и самый важный шаг.
    uploaded_filename = upload_image_from_base64(image)
    if not uploaded_filename:
        return {"error": "Не смог загрузить твою картинку."}

    # 2. Загружаем наш шаблон workflow
    with open('360.json', 'r') as f:
        prompt_workflow = json.load(f)

    # 3. Модифицируем воркфлоу на лету. В ноду загрузки подставляем имя нашего файла.
    # Используем ID ноды, который ты дал: '142'
    prompt_workflow['508']['inputs']['image'] = uploaded_filename

    # 4. Подключаемся к WebSocket и отправляем задачу
    try:
        ws = websocket.WebSocket()
        ws.connect(f"ws://{COMFYUI_API_ADDRESS}/ws?clientId={CLIENT_ID}")
        
        queued_prompt = queue_prompt(prompt_workflow)
        if not queued_prompt:
            ws.close()
            return {"error": "Не удалось поставить задачу в очередь"}

        # 5. Получаем результат, зная ID конечной ноды '506'
        output = get_image_data(ws, queued_prompt['prompt_id'], '506')
        ws.close()
    except Exception as e:
        return {"error": f"Произошла общая ошибка WebSocket: {e}"}

    return output

if __name__ == "__main__":
    print("Стартуем сервер-обработчик для RunPod...")
    time.sleep(120) 
    runpod.serverless.start({"handler": handler})
