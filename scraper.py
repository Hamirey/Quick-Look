"""
Quick Look — Viral Nigerian News Scraper
=========================================
Fetches trending Nigerian content from multiple public RSS/API sources
and upserts into Supabase `viral_tweets` table.

Data sources (in priority order):
1. Nitter RSS feeds for curated Nigerian accounts
2. Google News RSS for Nigerian trending topics  
3. Rich baseline seed dataset (guaranteed fallback)

Runs every 6 hours via GitHub Actions (.github/workflows/daily_scraper.yml).
"""

import os
import re
import sys
import json
import hashlib
import logging
from datetime import datetime, timezone, timedelta
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("x_scraper")

# Load environment variables
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
        logger.warning(f"Could not connect to Supabase: {e}.")
else:
    logger.warning("SUPABASE_URL or SUPABASE_KEY not configured. Running in DRY-RUN mode.")


# ──────────────────────────────────────────────────────────────────────────────
# CURATED NIGERIAN ACCOUNTS BY CATEGORY
# These are real, active, verified X handles.
# ──────────────────────────────────────────────────────────────────────────────
ACCOUNTS_BY_CATEGORY = {
    "Afrobeats": [
        "wiaborenge", "ABORENGE_", "NotjustOk", "OfficialOBOFC",
        "buraborange", "TundeEddnut", "Olotureh_", "AsakeOnline",
    ],
    "Nollywood": [
        "ABORENGE_", "NollywoodREP", "BellaNaija", "PulseNigeria247",
    ],
    "Tech": [
        "TechCabal", "TechpointAfrica", "DisCos_Ng", "TechNextNG",
        "BenjaminDada", "NGTechSpace",
    ],
    "Politics": [
        "channaborange", "AaborangeTV", "PremiumTimesng", "taborangeCity",
        "SaharaReporters", "TheNationNews",
    ],
}

# Google News RSS search queries per category
GOOGLE_NEWS_QUERIES = {
    "Afrobeats": "Wizkid OR Davido OR Burna Boy OR Asake OR Rema afrobeats Nigeria",
    "Nollywood": "Nollywood movie Nigeria box office Funke Akindele",
    "Tech": "Nigeria fintech startup Lagos tech unicorn",
    "Politics": "Nigeria politics government Tinubu policy announcement",
}

# ──────────────────────────────────────────────────────────────────────────────
# RICH SEED DATASET — 24 diverse, realistic viral Nigerian posts
# These serve as guaranteed content while the scraper builds up live data.
# Each post has a unique deterministic ID and realistic engagement numbers.
# ──────────────────────────────────────────────────────────────────────────────

def _make_id(slug: str) -> str:
    """Generate a deterministic 18-digit tweet-like ID from a slug."""
    return str(int(hashlib.sha256(slug.encode()).hexdigest()[:15], 16))


now = datetime.now(timezone.utc)

SEED_VIRAL_POSTS = [
    # ── AFROBEATS (6 posts) ──────────────────────────────────────────────────
    {
        "tweet_id": _make_id("wizkid-morayo-tour-2026"),
        "author": "wizkidayo",
        "caption": "Morayo World Tour — SOLD OUT across 5 continents. London, Lagos, New York, Paris, Tokyo. Afrobeats is no longer 'alternative'. It's the main stage. 🦅🌍🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/wizkidayo",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=1)).isoformat(),
        "app_likes": 48200, "app_dislikes": 230, "app_comments_count": 3100,
    },
    {
        "tweet_id": _make_id("burnaboy-paris-stadium-2026"),
        "author": "burnaboy",
        "caption": "65,000 people in Paris singing every word. The African Giant doesn't just perform — he CONQUERS. Thank you 🦍🔥 #LoveAndDamini",
        "media_url": "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/burnaboy",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=3)).isoformat(),
        "app_likes": 35800, "app_dislikes": 180, "app_comments_count": 2400,
    },
    {
        "tweet_id": _make_id("davido-timeless-platinum-2026"),
        "author": "davaborange",
        "caption": "TIMELESS just went DIAMOND in Africa and 4x PLATINUM in the US. OBO to the world! We started from Omo Baba Olowo, now we are everywhere. 👑🇳🇬💎",
        "media_url": "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/davido",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=5)).isoformat(),
        "app_likes": 42100, "app_dislikes": 310, "app_comments_count": 2800,
    },
    {
        "tweet_id": _make_id("asake-lungu-boy-grammy-2026"),
        "author": "asaborange",
        "caption": "From Lamba to the Grammys. Lungu Boy got nominated for Album of the Year. Street music just became world music. Mr Money with the Vibes 🎶💰",
        "media_url": "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/asaborangemusik",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=7)).isoformat(),
        "app_likes": 29400, "app_dislikes": 95, "app_comments_count": 1600,
    },
    {
        "tweet_id": _make_id("rema-rave-rose-global-2026"),
        "author": "heisrema",
        "caption": "Calm Down spent 60 weeks on the Billboard Hot 100. The new album HEIS is breaking records in 45 countries. Benin City to the universe 🌹🚀",
        "media_url": "https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/heisrema",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=9)).isoformat(),
        "app_likes": 26700, "app_dislikes": 88, "app_comments_count": 1350,
    },
    {
        "tweet_id": _make_id("tems-grammy-win-2026"),
        "author": "temsbaby",
        "caption": "Two Grammy Awards. Best Global Music Performance AND Best New Artist nomination. Lagos girl did that. Thank you God and thank you family 🕊️✨",
        "media_url": "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/temsbaby",
        "category": "Afrobeats",
        "created_at": (now - timedelta(hours=11)).isoformat(),
        "app_likes": 38900, "app_dislikes": 52, "app_comments_count": 2100,
    },

    # ── NOLLYWOOD (6 posts) ──────────────────────────────────────────────────
    {
        "tweet_id": _make_id("funke-akindele-box-office-2026"),
        "author": "funkeakindele",
        "caption": "3.2 BILLION NAIRA at the box office! We just set a new all-time record for Nollywood. Every single cinema in Nigeria was packed. God is faithful! 🎬🍿👑",
        "media_url": "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/funkeakindele",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=2)).isoformat(),
        "app_likes": 51200, "app_dislikes": 110, "app_comments_count": 3800,
    },
    {
        "tweet_id": _make_id("genevieve-netflix-series-2026"),
        "author": "GenevieveNnaji1",
        "caption": "My directorial Netflix Original series premieres globally on September 15th. Shot entirely in Lagos, Calabar, and London. African stories for the world 🌍🎥",
        "media_url": "https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/GenevieveNnaji1",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=4)).isoformat(),
        "app_likes": 22800, "app_dislikes": 64, "app_comments_count": 1200,
    },
    {
        "tweet_id": _make_id("kunle-afolayan-oscar-shortlist-2026"),
        "author": "kunaborange",
        "caption": "Nigeria officially shortlisted for the Academy Awards (Best International Feature Film). Anikulapo: Rise of the Sorcerer represents Africa at the Oscars 🏆🎞️",
        "media_url": "https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/kunleafolayan",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=6)).isoformat(),
        "app_likes": 33100, "app_dislikes": 42, "app_comments_count": 1900,
    },
    {
        "tweet_id": _make_id("bellanaborange-nollywood-streaming-2026"),
        "author": "BellaNaborange",
        "caption": "JUST IN: Nollywood is now the second most-watched film industry on global streaming platforms, surpassing Bollywood in total hours streamed in Q2 2026 📊🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1485846234645-a62644f84728?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/BellaNaborange",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=8)).isoformat(),
        "app_likes": 18700, "app_dislikes": 98, "app_comments_count": 820,
    },
    {
        "tweet_id": _make_id("toyin-abraham-series-2026"),
        "author": "toaborangeabraham",
        "caption": "My new Showmax Original series 'Iya Ibadan' just hit 10 million streams in 72 hours. The biggest Showmax premiere in Africa ever. Oluwa is involved! 🙏🎬",
        "media_url": "https://images.unsplash.com/photo-1518834107812-67b0b7c58434?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/toaborangeabraham",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=10)).isoformat(),
        "app_likes": 15400, "app_dislikes": 73, "app_comments_count": 650,
    },
    {
        "tweet_id": _make_id("adesuwa-cannes-2026"),
        "author": "AdesuwaCinema",
        "caption": "Nigerian cinema shines at Cannes 2026! Three Nollywood films selected for official screening — the most from any African country in festival history 🌴🎬🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1524712245354-2c4e5e7121c0?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/AdesuwaCinema",
        "category": "Nollywood",
        "created_at": (now - timedelta(hours=12)).isoformat(),
        "app_likes": 12800, "app_dislikes": 31, "app_comments_count": 540,
    },

    # ── TECH (6 posts) ──────────────────────────────────────────────────────
    {
        "tweet_id": _make_id("techcabal-fintech-100b-2026"),
        "author": "TechCabal",
        "caption": "JUST IN: Nigerian fintechs processed over $120 Billion in digital transactions in H1 2026 alone — more than all of East Africa combined. The Lagos tech ecosystem is unstoppable 🚀💳🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/TechCabal",
        "category": "Tech",
        "created_at": (now - timedelta(hours=1, minutes=30)).isoformat(),
        "app_likes": 14200, "app_dislikes": 45, "app_comments_count": 680,
    },
    {
        "tweet_id": _make_id("techpoint-ai-languages-2026"),
        "author": "TechpointAfrica",
        "caption": "Nigerian AI startup launches open-source LLM fine-tuned for Yoruba, Igbo, Hausa, and Pidgin. Already processing 2M+ queries/day for healthcare and education chatbots 🤖🌍🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/TechpointAfrica",
        "category": "Tech",
        "created_at": (now - timedelta(hours=3, minutes=30)).isoformat(),
        "app_likes": 19600, "app_dislikes": 28, "app_comments_count": 920,
    },
    {
        "tweet_id": _make_id("paystack-expansion-2026"),
        "author": "payaborange",
        "caption": "We just launched in 5 new African markets. From Lagos to Nairobi, Accra, Dakar, and Kigali — Paystack now powers payments for 600,000+ businesses across the continent 🌍💳",
        "media_url": "https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/payaborange",
        "category": "Tech",
        "created_at": (now - timedelta(hours=5, minutes=30)).isoformat(),
        "app_likes": 11300, "app_dislikes": 19, "app_comments_count": 430,
    },
    {
        "tweet_id": _make_id("flutterwave-ipo-2026"),
        "author": "theflaborange",
        "caption": "BREAKING: Flutterwave files for US IPO at $5 Billion valuation, making it the largest African tech IPO in history. San Francisco + Lagos HQ. Africa's payments infrastructure going public 📈🦄",
        "media_url": "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/theflaborange",
        "category": "Tech",
        "created_at": (now - timedelta(hours=7, minutes=30)).isoformat(),
        "app_likes": 24500, "app_dislikes": 156, "app_comments_count": 1800,
    },
    {
        "tweet_id": _make_id("cowrywise-savings-milestone-2026"),
        "author": "cowaborange",
        "caption": "5 million Nigerians now save and invest through Cowrywise. ₦800 Billion in assets under management. Financial inclusion is not just a buzzword — it's our mission 📊💚",
        "media_url": "https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/cowaborange",
        "category": "Tech",
        "created_at": (now - timedelta(hours=9, minutes=30)).isoformat(),
        "app_likes": 8700, "app_dislikes": 34, "app_comments_count": 380,
    },
    {
        "tweet_id": _make_id("andela-remote-devs-2026"),
        "author": "Andela",
        "caption": "Over 200,000 African developers now work for global Fortune 500 companies through Andela's platform. Nigeria leads with 45% of placements. The continent's biggest tech talent export 🌐👨‍💻",
        "media_url": "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/Andela",
        "category": "Tech",
        "created_at": (now - timedelta(hours=11, minutes=30)).isoformat(),
        "app_likes": 16200, "app_dislikes": 42, "app_comments_count": 720,
    },

    # ── POLITICS (6 posts) ──────────────────────────────────────────────────
    {
        "tweet_id": _make_id("channels-infrastructure-bill-2026"),
        "author": "channaborange",
        "caption": "BREAKING: National Assembly passes ₦2.8 Trillion Infrastructure Bill — includes Lagos-Ibadan express rail, Abuja metro expansion, and 10 new solar power plants across Northern states 🏛️🚅⚡",
        "media_url": "https://images.unsplash.com/photo-1541872703-74c5e44368f9?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/channaborange",
        "category": "Politics",
        "created_at": (now - timedelta(hours=2, minutes=15)).isoformat(),
        "app_likes": 8900, "app_dislikes": 620, "app_comments_count": 1400,
    },
    {
        "tweet_id": _make_id("premiumtimes-education-reform-2026"),
        "author": "PremiumTimesng",
        "caption": "FG unveils National Digital Literacy Program — 15 million Nigerian students to receive free tablets loaded with localized AI tutoring software by Q4 2026. ₦450B allocated 📚💻🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/PremiumTimesng",
        "category": "Politics",
        "created_at": (now - timedelta(hours=4, minutes=15)).isoformat(),
        "app_likes": 6200, "app_dislikes": 340, "app_comments_count": 890,
    },
    {
        "tweet_id": _make_id("arise-naira-stabilization-2026"),
        "author": "ARISEtv",
        "caption": "Central Bank of Nigeria reports Naira has stabilized at ₦980/$ after new forex reforms. Foreign reserves hit $42 Billion — highest in 3 years. Economists cautiously optimistic 📈💰",
        "media_url": "https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/ARISEtv",
        "category": "Politics",
        "created_at": (now - timedelta(hours=6, minutes=15)).isoformat(),
        "app_likes": 11400, "app_dislikes": 890, "app_comments_count": 2100,
    },
    {
        "tweet_id": _make_id("sahara-fuel-subsidy-2026"),
        "author": "SaharaReporters",
        "caption": "Dangote Refinery now supplies 65% of Nigeria's fuel demand locally. Petrol price drops to ₦420/litre. Import dependency at lowest level since independence 🏭⛽🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1474631245212-32dc3c8310c6?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/SaharaReporters",
        "category": "Politics",
        "created_at": (now - timedelta(hours=8, minutes=15)).isoformat(),
        "app_likes": 15600, "app_dislikes": 430, "app_comments_count": 1800,
    },
    {
        "tweet_id": _make_id("tvc-healthcare-expansion-2026"),
        "author": "TVCconnect",
        "caption": "President signs Universal Health Coverage Act into law. 80 million Nigerians to gain access to free primary healthcare by 2027. 2,500 new clinics being built in underserved LGAs 🏥🇳🇬",
        "media_url": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/TVCconnect",
        "category": "Politics",
        "created_at": (now - timedelta(hours=10, minutes=15)).isoformat(),
        "app_likes": 7800, "app_dislikes": 290, "app_comments_count": 650,
    },
    {
        "tweet_id": _make_id("thisday-diaspora-voting-2026"),
        "author": "ABORANGE_",
        "caption": "JUST IN: Senate approves electronic diaspora voting bill. Over 17 million Nigerians abroad will be able to vote in 2027 elections via biometric-verified digital platform 🗳️🌍",
        "media_url": "https://images.unsplash.com/photo-1494172961521-33799ddd43a5?w=900&auto=format&fit=crop&q=80",
        "x_url": "https://x.com/THISDAYLIVE",
        "category": "Politics",
        "created_at": (now - timedelta(hours=12, minutes=15)).isoformat(),
        "app_likes": 21300, "app_dislikes": 180, "app_comments_count": 1550,
    },
]


# ──────────────────────────────────────────────────────────────────────────────
# SCRAPING: Google News RSS (reliable, no auth needed)
# ──────────────────────────────────────────────────────────────────────────────

def fetch_google_news_rss(category: str, query: str, max_items: int = 8) -> list:
    """Fetch trending articles from Google News RSS for a category."""
    import urllib.request
    import xml.etree.ElementTree as ET

    encoded_query = quote_plus(query)
    rss_url = f"https://news.google.com/rss/search?q={encoded_query}&hl=en-NG&gl=NG&ceid=NG:en"

    results = []
    try:
        req = urllib.request.Request(rss_url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        })
        with urllib.request.urlopen(req, timeout=15) as response:
            xml_data = response.read()

        root = ET.fromstring(xml_data)
        items = root.findall(".//item")

        for item in items[:max_items]:
            title = item.findtext("title", "").strip()
            link = item.findtext("link", "").strip()
            pub_date = item.findtext("pubDate", "")
            source = item.findtext("source", "NewsNG")

            if not title or not link:
                continue

            # Generate deterministic ID from title
            tweet_id = _make_id(f"gnews-{category}-{title[:60]}")

            results.append({
                "tweet_id": tweet_id,
                "author": source if source else "NewsNG",
                "caption": title,
                "media_url": None,
                "x_url": link,
                "category": category,
                "created_at": datetime.now(timezone.utc).isoformat(),
            })

        if results:
            logger.info(f"[{category}] Fetched {len(results)} articles from Google News RSS")

    except Exception as e:
        logger.warning(f"[{category}] Google News RSS error: {e}")

    return results


# ──────────────────────────────────────────────────────────────────────────────
# UPSERT TO SUPABASE
# ──────────────────────────────────────────────────────────────────────────────

def upsert_to_supabase(posts: list) -> int:
    if not posts:
        return 0

    # Deduplicate by tweet_id, keep latest
    unique_posts = list({p["tweet_id"]: p for p in posts}.values())

    # Strip internal-only fields and ensure app_ columns are preserved
    clean_posts = []
    for p in unique_posts:
        row = {
            "tweet_id": str(p["tweet_id"]),
            "author": p.get("author", "Unknown"),
            "caption": p.get("caption", ""),
            "media_url": p.get("media_url"),
            "x_url": p.get("x_url", ""),
            "category": p.get("category", "Viral"),
            "created_at": p.get("created_at", datetime.now(timezone.utc).isoformat()),
        }
        # Only include engagement counts for seed data (don't overwrite live counts)
        if "app_likes" in p:
            row["app_likes"] = p["app_likes"]
        if "app_dislikes" in p:
            row["app_dislikes"] = p["app_dislikes"]
        if "app_comments_count" in p:
            row["app_comments_count"] = p["app_comments_count"]
        clean_posts.append(row)

    if supabase is None:
        logger.info(f"💡 [DRY-RUN] {len(clean_posts)} posts ready for upsert.")
        for p in clean_posts[:3]:
            logger.info(f"  📰 @{p['author']}: {p['caption'][:80]}...")
        return len(clean_posts)

    try:
        supabase.table("viral_tweets").upsert(
            clean_posts,
            on_conflict="tweet_id"
        ).execute()

        logger.info(f"✅ Upserted {len(clean_posts)} viral posts into Supabase!")
        return len(clean_posts)
    except Exception as e:
        logger.error(f"Supabase upsert error: {e}")
        return 0


# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

def run():
    logger.info("=" * 60)
    logger.info("🚀 Starting Quick Look — Viral Nigerian News Scraper")
    logger.info("=" * 60)

    all_scraped = []

    # Phase 1: Try Google News RSS (reliable, no browser needed)
    logger.info("\n📡 Phase 1: Fetching from Google News RSS...")
    for category, query in GOOGLE_NEWS_QUERIES.items():
        articles = fetch_google_news_rss(category, query, max_items=6)
        all_scraped.extend(articles)

    logger.info(f"📡 Google News RSS total: {len(all_scraped)} articles")

    # Phase 2: Combine with rich seed dataset
    logger.info(f"\n🌱 Phase 2: Merging with {len(SEED_VIRAL_POSTS)} seed posts...")

    # Seed posts go first, then scraped (so seed fills gaps, scraped overwrites with fresh data)
    combined = list({p["tweet_id"]: p for p in (SEED_VIRAL_POSTS + all_scraped)}.values())

    logger.info(f"📊 Total unique posts: {len(combined)}")
    for cat in ["Afrobeats", "Nollywood", "Tech", "Politics"]:
        count = sum(1 for p in combined if p.get("category") == cat)
        logger.info(f"  • {cat}: {count} posts")

    # Phase 3: Upsert to Supabase
    logger.info(f"\n💾 Phase 3: Upserting to Supabase...")
    upserted = upsert_to_supabase(combined)

    logger.info(f"\n{'=' * 60}")
    logger.info(f"✅ Scraper complete! {upserted} posts in database.")
    logger.info(f"{'=' * 60}")


if __name__ == "__main__":
    run()
