import os
import re
import sys
import json
import logging
from datetime import datetime, timezone
from urllib.parse import quote_plus
from dotenv import load_dotenv
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("x_scraper")

# Load environment variables from .env file
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase = None
if SUPABASE_URL and SUPABASE_KEY and "your-project-id" not in SUPABASE_URL:
    try:
        from supabase import create_client, Client
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        logger.info(f"Supabase client initialized: {SUPABASE_URL}")
    except Exception as e:
        logger.warning(f"Could not connect to Supabase: {e}. Running in DRY-RUN mode.")
else:
    logger.warning(
        "\n=======================================================\n"
        "ℹ️  NOTE: SUPABASE_URL or SUPABASE_KEY not configured.\n"
        "   Running in DRY-RUN MODE (Scraping and displaying data).\n"
        "=======================================================\n"
    )

# List of active public X / Nitter mirror instances with fallbacks
MIRROR_INSTANCES = [
    "https://xcancel.com",
    "https://nitter.net",
    "https://nitter.poast.org",
    "https://nitter.lucabased.xyz",
    "https://nitter.privacydev.net"
]

# Category search queries targeting viral Nigerian content
CATEGORIES = {
    "Afrobeats": [
        '(Afrobeats OR Wizkid OR Burna OR Davido OR Asake OR Rema) min_faves:500',
        '(Afrobeats OR Wizkid OR Burna OR Davido OR Asake) min_faves:100',
        'Afrobeats'
    ],
    "Nollywood": [
        '(Nollywood OR "Nigerian movie" OR "Funke Akindele" OR "Genevieve Nnaji") min_faves:500',
        '(Nollywood OR "Nigerian movie" OR "Funke Akindele") min_faves:100',
        'Nollywood'
    ],
    "Tech": [
        '("Nigeria tech" OR "Lagos tech" OR Flutterwave OR Paystack OR "tech in Nigeria") min_faves:500',
        '("Nigeria tech" OR "Lagos tech" OR Flutterwave OR Paystack) min_faves:100',
        'Nigeria tech'
    ],
    "Politics": [
        '(Tinubu OR "Peter Obi" OR INEC OR "Nigerian politics" OR "Nigeria government") min_faves:500',
        '(Tinubu OR "Peter Obi" OR "Nigerian politics") min_faves:100',
        'Nigeria politics'
    ]
}


def clean_text(text: str) -> str:
    """Normalize text and remove excessive whitespace."""
    if not text:
        return ""
    return re.sub(r"\s+", " ", text).strip()


def extract_tweet_id_from_url(url: str) -> str:
    """Extract numeric tweet ID from tweet status URL."""
    match = re.search(r"/status/(\d+)", url)
    return match.group(1) if match else ""


def scrape_category(page, base_url: str, category: str, query: str, max_items: int = 15) -> list:
    """Scrape viral tweets for a given category from a mirror instance."""
    encoded_query = quote_plus(query)
    search_url = f"{base_url}/search?f=tweets&q={encoded_query}"
    logger.info(f"[{category}] Querying: {search_url}")

    results = []

    try:
        page.goto(search_url, wait_until="domcontentloaded", timeout=18000)
        try:
            page.wait_for_selector(".timeline-item, .timeline-none, .tweet-body", timeout=6000)
        except PlaywrightTimeoutError:
            logger.warning(f"[{category}] Timeout on {base_url}.")
            return results

        tweet_elements = page.query_selector_all(".timeline-item")
        if not tweet_elements:
            tweet_elements = page.query_selector_all(".tweet-body")

        logger.info(f"[{category}] Found {len(tweet_elements)} timeline items.")

        for tweet_el in tweet_elements:
            if len(results) >= max_items:
                break

            if tweet_el.query_selector(".unavailable-box"):
                continue

            link_el = tweet_el.query_selector(".tweet-link")
            if not link_el:
                continue

            href = link_el.get_attribute("href") or ""
            tweet_id = extract_tweet_id_from_url(href)
            if not tweet_id:
                continue

            status_path = re.sub(r"#.*$", "", href).lstrip("/")
            canonical_x_url = f"https://x.com/{status_path}"

            author_el = tweet_el.query_selector(".fullname") or tweet_el.query_selector(".username")
            author = clean_text(author_el.inner_text()) if author_el else "Unknown"

            content_el = tweet_el.query_selector(".tweet-content")
            caption = clean_text(content_el.inner_text()) if content_el else ""

            # Extract media URL
            media_url = None
            video_el = tweet_el.query_selector(".attachment.video-container video, video source")
            if video_el:
                media_url = video_el.get_attribute("src")

            if not media_url:
                img_el = tweet_el.query_selector(".attachment.image img, .still-image img, .gallery-image img")
                if img_el:
                    media_url = img_el.get_attribute("src")

            if media_url and media_url.startswith("/"):
                media_url = f"{base_url}{media_url}"

            # Extract timestamp
            date_el = tweet_el.query_selector(".tweet-date a")
            created_at = datetime.now(timezone.utc).isoformat()
            if date_el:
                date_title = date_el.get_attribute("title")
                if date_title:
                    try:
                        parsed_dt = datetime.strptime(date_title.replace(" · ", " "), "%b %d, %Y %I:%M %p %Z")
                        created_at = parsed_dt.replace(tzinfo=timezone.utc).isoformat()
                    except Exception:
                        pass

            post_data = {
                "tweet_id": str(tweet_id),
                "author": author,
                "caption": caption,
                "media_url": media_url,
                "x_url": canonical_x_url,
                "category": category,
                "created_at": created_at
            }
            results.append(post_data)

    except Exception as err:
        logger.error(f"[{category}] Error during scraping on {base_url}: {err}")

    return results


def upsert_to_supabase(posts: list) -> int:
    """Upsert posts into the Supabase viral_tweets table."""
    if not posts:
        logger.info("No posts to sync.")
        return 0

    unique_posts = list({p["tweet_id"]: p for p in posts}.values())

    if supabase is None:
        logger.info(f"💡 [DRY-RUN] Would have upserted {len(unique_posts)} posts to Supabase.")
        preview_file = "scraped_preview.json"
        with open(preview_file, "w", encoding="utf-8") as f:
            json.dump(unique_posts, f, indent=2, ensure_ascii=False)
        logger.info(f"📄 Saved {len(unique_posts)} scraped posts to '{preview_file}' for review.")
        return len(unique_posts)

    try:
        supabase.table("viral_tweets").upsert(
            unique_posts,
            on_conflict="tweet_id"
        ).execute()

        logger.info(f"✅ Successfully upserted {len(unique_posts)} posts into Supabase viral_tweets table.")
        return len(unique_posts)
    except Exception as e:
        logger.error(f"Failed to upsert posts to Supabase: {e}")
        raise e


def run():
    """Main execution flow across all categories."""
    logger.info("Starting automated Playwright scraper for viral Nigerian tweets...")
    all_posts = []

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu"
            ]
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for category, query_list in CATEGORIES.items():
            category_posts = []
            for query in query_list:
                for mirror in MIRROR_INSTANCES:
                    try:
                        category_posts = scrape_category(page, mirror, category, query)
                        if category_posts:
                            logger.info(f"[{category}] Successfully scraped {len(category_posts)} posts from {mirror}")
                            break
                    except Exception as ex:
                        logger.warning(f"[{category}] Failed on {mirror}: {ex}")

                if category_posts:
                    break

            all_posts.extend(category_posts)

        browser.close()

    logger.info(f"Total posts scraped across all categories: {len(all_posts)}")
    if all_posts:
        upsert_to_supabase(all_posts)


if __name__ == "__main__":
    run()
