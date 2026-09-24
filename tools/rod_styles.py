"""Linear RGB palettes shared by authored tackle and runtime golf cosmetics."""
import json
from pathlib import Path
ROD_STYLES = json.loads((Path(__file__).resolve().parents[1] / 'assets/equipment/tackle_styles.json').read_text())
