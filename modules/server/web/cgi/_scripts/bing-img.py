#!/usr/bin/env python3
import json
import urllib.request
import sys

def main():
    # 1. Fetch the JSON from Bing
    api_url = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1"
    
    try:
        with urllib.request.urlopen(api_url) as response:
            # 2. Read and parse JSON
            data = json.loads(response.read().decode())
            
            # 3. Extract the image URL
            # The URL is typically a relative path like "/th?id=..."
            relative_url = data["images"][0]["url"]
            full_url = "https://www.bing.com" + relative_url
            
            # 4. Redirect to the image
            print("Status: 302 Found")
            print(f"Location: {full_url}")
            print("Content-Type: text/plain; charset=utf-8")
            print()  # Mandatory empty line after headers
            print("Redirecting...")
            
    except Exception as e:
        # Fallback or error reporting
        print("Content-Type: text/plain")
        print()
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main()
