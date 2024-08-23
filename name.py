#!/usr/bin/env python3

import pygame
import psutil
import time

# Initialize Pygame
pygame.init()

# Set up display
screen = pygame.display.set_mode((480, 320))

# Define colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# Define font
font = pygame.font.Font(None, 36)

def display_network_stats():
    net_io = psutil.net_io_counters()
    screen.fill(BLACK)
    
    # Render network stats text
    text = font.render(f"Sent: {net_io.bytes_sent / 1024 / 1024:.2f} MB", True, WHITE)
    screen.blit(text, (20, 50))
    
    text = font.render(f"Recv: {net_io.bytes_recv / 1024 / 1024:.2f} MB", True, WHITE)
    screen.blit(text, (20, 100))
    
    pygame.display.flip()

def display_system_info():
    cpu_usage = psutil.cpu_percent()
    memory_info = psutil.virtual_memory()
    screen.fill(BLACK)
    
    # Render CPU and memory info text
    text = font.render(f"CPU Usage: {cpu_usage}%", True, WHITE)
    screen.blit(text, (20, 50))
    
    text = font.render(f"Memory Usage: {memory_info.percent}%", True, WHITE)
    screen.blit(text, (20, 100))
    
    pygame.display.flip()

def main():
    running = True
    screen_choice = 0

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_1:
                    screen_choice = 0
                elif event.key == pygame.K_2:
                    screen_choice = 1

        if screen_choice == 0:
            display_network_stats()
        elif screen_choice == 1:
            display_system_info()
        
        time.sleep(1)

    pygame.quit()

if __name__ == "__main__":
    main()
