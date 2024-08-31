import pygame
import requests

# Initialize Pygame
pygame.init()

# Set up display
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Internet Usage Display")

# Define colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# Set up font
font = pygame.font.Font(None, 36)

def fetch_internet_usage():
    prometheus_url = "http://<prometheus-ip>:9090/api/v1/query"
    queries = {
        "upload": "rate(node_network_transmit_bytes_total[1m])",
        "download": "rate(node_network_receive_bytes_total[1m])",
        "total_upload": "sum(increase(node_network_transmit_bytes_total[1d]))",
        "total_download": "sum(increase(node_network_receive_bytes_total[1d]))"
    }
    data = {}
    for key, query in queries.items():
        response = requests.get(prometheus_url, params={'query': query})
        if response.status_code == 200:
            result = response.json()['data']['result']
            if result:
                data[key] = float(result[0]['value'][1])
            else:
                data[key] = 0.0
        else:
            data[key] = None
    return data

def display_data():
    data = fetch_internet_usage()
    screen.fill(BLACK)
    
    # Render data text
    y_offset = 50
    for key, value in data.items():
        text = font.render(f"{key}: {value:.2f} bytes/sec" if "rate" in key else f"{key}: {value:.2f} bytes", True, WHITE)
        screen.blit(text, (20, y_offset))
        y_offset += 50
    
    pygame.display.flip()

# Main loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    
    display_data()
    pygame.time.wait(1000)  # Update every second

pygame.quit()
