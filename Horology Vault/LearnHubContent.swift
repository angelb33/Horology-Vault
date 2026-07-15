//
//  LearnHubContent.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/15/26.
//

import Foundation

/// The eight top-level groupings shown as `Section`s in `LearnHubView`'s list.
enum LearnCategory: String, CaseIterable, Identifiable {
    case anatomy = "Watch Anatomy"
    case movements = "Movements"
    case complications = "Complications"
    case materials = "Materials & Case"
    case straps = "Straps & Bracelets"
    case maintenance = "Care & Maintenance"
    case buying = "Buying & Ownership"
    case glossary = "Glossary"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .anatomy: "circle.grid.cross"
        case .movements: "gearshape.2"
        case .complications: "puzzlepiece.extension"
        case .materials: "cube"
        case .straps: "link"
        case .maintenance: "wrench.and.screwdriver"
        case .buying: "tag"
        case .glossary: "character.book.closed"
        }
    }
}

/// A single Learn Hub article. This is bundled reference content, not user data, so it's a
/// plain Swift literal (see `LearnHubContent` below) rather than a `@Model` — same reasoning
/// as `OfficialServiceContact`.
struct LearnTopic: Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let category: LearnCategory
    let title: String
    let summary: String
    let body: String

    /// Set only for topics in `.complications` that correspond to one of a watch's
    /// `complications` strings. Must exactly match an entry in `Watch.commonComplications` —
    /// enforced by `LearnHubContentTests` — so `LearnHubView` can reliably cross-link to the
    /// user's own watches that have this complication.
    var complicationName: String?

    /// A per-topic SF Symbol, distinct from `category.systemImage`, so a category's rows read
    /// as individually identifiable articles rather than a repeated icon stamped down a list.
    /// Falls back to the category's icon when nil (only relevant for topics added later without
    /// picking a specific symbol).
    var systemImage: String?

    init(
        slug: String,
        category: LearnCategory,
        title: String,
        summary: String,
        body: String,
        complicationName: String? = nil,
        systemImage: String? = nil
    ) {
        self.slug = slug
        self.category = category
        self.title = title
        self.summary = summary
        self.body = body
        self.complicationName = complicationName
        self.systemImage = systemImage
    }

    var displaySystemImage: String {
        systemImage ?? category.systemImage
    }
}

/// Bundled as Swift literals rather than JSON, same rationale as `OfficialServiceDirectory`:
/// static, read-only, ships-with-the-app content that doesn't need a bundle resource file.
enum LearnHubContent {
    static let topics: [LearnTopic] = anatomyTopics + movementTopics + complicationTopics
        + materialTopics + strapTopics + maintenanceTopics + buyingTopics + glossaryTopics

    private static let anatomyTopics: [LearnTopic] = [
        LearnTopic(
            slug: "anatomy-case",
            category: .anatomy,
            title: "Case",
            summary: "The housing that protects the movement and holds everything else together.",
            body: """
            The case is the watch's outer shell — it holds the movement, dial, and crystal, and is where \
            the crown, lugs, and bezel all attach. Cases are usually described by diameter (measured edge \
            to edge, not including the crown) and thickness, both of which affect how a watch wears on \
            the wrist far more than most people expect.

            A case is rarely one solid block: it typically comes apart into a case back, a middle case, \
            and the crystal, sealed with gaskets to keep water and dust out. How well those gaskets are \
            maintained is a big part of why water resistance can degrade over time even on a watch that's \
            never been opened.
            """,
            systemImage: "square.on.circle"
        ),
        LearnTopic(
            slug: "anatomy-crown",
            category: .anatomy,
            title: "Crown",
            summary: "The knob on the side of the case used to wind, set the time, and set the date.",
            body: """
            The crown is the small knob, usually on the right side of the case, used to manually wind a \
            mechanical movement, set the time, and (on most watches) set the date. Pulling it out to \
            different "clicks" or positions changes what it controls — winding at the resting position, \
            date-setting at the first pull, time-setting at the last.

            Screw-down crowns thread into the case rather than just pushing in, adding an extra seal that \
            meaningfully improves water resistance — this is why dive watches almost always have one. \
            Forgetting to screw a crown back in after setting the time is one of the most common ways an \
            otherwise water-resistant watch lets moisture in.
            """,
            systemImage: "crown"
        ),
        LearnTopic(
            slug: "anatomy-crystal",
            category: .anatomy,
            title: "Crystal",
            summary: "The transparent cover over the dial — usually mineral, sapphire, or acrylic.",
            body: """
            The crystal is the clear cover protecting the dial and hands. It's not glass in the everyday \
            sense — the three common materials (mineral, sapphire, and acrylic) trade off scratch \
            resistance, shatter resistance, and cost very differently, which is covered in more depth \
            under Materials & Case.

            Some crystals are domed (adding a vintage look and a bit of light distortion at the edges) \
            and some have an anti-reflective coating on one or both sides to reduce glare when reading \
            the dial at an angle.
            """,
            systemImage: "diamond"
        ),
        LearnTopic(
            slug: "anatomy-bezel",
            category: .anatomy,
            title: "Bezel",
            summary: "The ring around the crystal — sometimes fixed, sometimes rotating with a function.",
            body: """
            The bezel is the ring surrounding the crystal. On plenty of watches it's purely decorative and \
            fixed in place, but on many tool watches it rotates and does real work: a dive bezel tracks \
            elapsed time and only turns counter-clockwise (so an accidental bump can only ever make it show \
            less time remaining, never more — a real safety margin underwater), a GMT bezel tracks a second \
            time zone, and a tachymeter bezel (common on chronographs) converts elapsed time into a speed.

            Bezels are usually described by their insert material (aluminum, ceramic, sapphire) and by \
            whether they click into fixed positions (unidirectional or bidirectional) or turn freely.
            """,
            systemImage: "circle.dotted"
        ),
        LearnTopic(
            slug: "anatomy-lugs",
            category: .anatomy,
            title: "Lugs",
            summary: "The projections at 12 and 6 o'clock that the strap or bracelet attaches to.",
            body: """
            Lugs are the four projections extending from the case — two at 12 o'clock, two at 6 — that \
            hold the spring bars connecting the strap or bracelet. The distance between the outer edges of \
            the top and bottom lugs is the "lug-to-lug" measurement, and it has a bigger effect on how a \
            watch fits a given wrist than the case diameter most listings lead with.

            "Lug width" (a separate measurement, the gap between the two lugs where the strap actually \
            threads through) determines which straps will physically fit — mismatching it is the most \
            common strap-shopping mistake for beginners.
            """,
            systemImage: "smallcircle.filled.circle"
        ),
        LearnTopic(
            slug: "anatomy-movement",
            category: .anatomy,
            title: "Movement",
            summary: "The engine inside the case that actually keeps time.",
            body: """
            The movement (sometimes called the "caliber") is the mechanism that keeps time and drives the \
            hands, date, and any complications. It sits inside the case, usually visible only through a \
            display case back if the manufacturer chose to include one.

            The three broad movement families — mechanical, automatic, and quartz — work in fundamentally \
            different ways and have very different maintenance needs; each gets its own topic under \
            Movements.
            """,
            systemImage: "gearshape.2.fill"
        ),
        LearnTopic(
            slug: "anatomy-dial",
            category: .anatomy,
            title: "Dial",
            summary: "The face of the watch — where hour markers, hands, and any subdials live.",
            body: """
            The dial (colloquially the "face") is the surface the hands sweep across. Its markers or \
            printed numerals are called "dial furniture," and small secondary dials for things like a \
            chronograph's running seconds or a moonphase display are called "subdials."

            Many dials use a luminous material on the markers and hands so the time can be read in the \
            dark — see Lume in the Glossary for how that actually works.
            """,
            systemImage: "circle.grid.3x3.fill"
        ),
        LearnTopic(
            slug: "anatomy-hands",
            category: .anatomy,
            title: "Hands",
            summary: "The hour, minute, and (usually) seconds indicators sweeping over the dial.",
            body: """
            Hands indicate the time by pointing to markers on the dial. Beyond the standard hour and \
            minute hands, most watches add a seconds hand, and complicated watches add more still — a \
            chronograph seconds hand, a GMT hand tracking a second time zone, and so on.

            Hand shapes are mostly an aesthetic choice (Dauphine, sword, cathedral, and Mercedes are common \
            named styles) but they're also a quick way to visually identify a watch family or era.
            """,
            systemImage: "clock.fill"
        ),
        LearnTopic(
            slug: "anatomy-strap",
            category: .anatomy,
            title: "Bracelet / Strap",
            summary: "What actually goes around the wrist and connects to the case at the lugs.",
            body: """
            The bracelet (metal, made of individual links) or strap (a single piece, usually leather, \
            rubber, or fabric) is what wraps around the wrist and attaches to the lugs via spring bars. It \
            ends in a clasp or buckle that closes it around the wrist.

            Straps & Bracelets has its own set of topics covering materials, clasp types, and sizing in \
            more depth.
            """,
            systemImage: "link.circle"
        )
    ]

    private static let movementTopics: [LearnTopic] = [
        LearnTopic(
            slug: "movement-mechanical",
            category: .movements,
            title: "Mechanical Movements",
            summary: "Powered by a hand-wound mainspring, with no battery at all.",
            body: """
            A mechanical movement stores energy in a coiled mainspring, wound by hand via the crown. That \
            energy releases gradually through a gear train to an escapement, which ticks it out at a \
            steady rate — this is the source of the smooth, sweeping-but-actually-stepped motion (typically \
            5-8 small steps per second) that distinguishes a mechanical seconds hand from a quartz one's \
            single once-per-second tick.

            Because it's a fully mechanical system with no battery, it needs regular winding to keep \
            running and periodic professional servicing (see Care & Maintenance) to keep it accurate, since \
            tiny amounts of wear and old lubricant gradually affect timekeeping.
            """,
            systemImage: "gearshape.fill"
        ),
        LearnTopic(
            slug: "movement-automatic",
            category: .movements,
            title: "Automatic Movements",
            summary: "A mechanical movement that winds itself from the motion of your wrist.",
            body: """
            An automatic (or "self-winding") movement is a mechanical movement with one addition: a \
            weighted rotor that spins with the natural motion of the wrist and winds the mainspring \
            automatically, so the watch doesn't need daily manual winding as long as it's worn regularly.

            If it sits unworn for a few days, it will run down and stop — restarting it usually just means \
            giving it a few manual winds via the crown (or wearing it) and resetting the time. A watch \
            winder (see Storage & Watch Winders) is a common way to keep an unworn automatic running and \
            ready to go.
            """,
            systemImage: "arrow.triangle.2.circlepath"
        ),
        LearnTopic(
            slug: "movement-quartz",
            category: .movements,
            title: "Quartz Movements",
            summary: "Battery-powered movements that use a vibrating quartz crystal for accuracy.",
            body: """
            A quartz movement uses a battery to send a small electric current through a tiny quartz \
            crystal, which vibrates at a precise, fixed frequency (32,768 times per second in almost every \
            watch). A circuit counts those vibrations and steps the seconds hand forward once per second.

            Quartz movements are dramatically more accurate than mechanical ones for a fraction of the \
            cost and need far less maintenance — mainly just a battery swap every year or two. Their rise \
            in the 1970s-80s nearly wiped out Swiss mechanical watchmaking; see Quartz Crisis in the \
            Glossary.
            """,
            systemImage: "waveform"
        ),
        LearnTopic(
            slug: "movement-power-reserve",
            category: .movements,
            title: "Power Reserve & Winding",
            summary: "How long a mechanical watch runs on a full wind, and how to wind one properly.",
            body: """
            Power reserve is how long a mechanical or automatic watch keeps running after being fully \
            wound and left untouched — commonly 40-70 hours, though some watches are built specifically \
            for multi-day or even multi-week reserves. Some watches display this on the dial as its own \
            complication (see Power Reserve under Complications).

            To hand-wind a movement, turn the crown clockwise in its resting (unpulled) position, usually \
            20-40 turns, until you feel resistance — most movements have a slipping mainspring clutch so \
            you can't actually overwind it, but stop once it feels noticeably tighter rather than forcing \
            it. Automatics can be wound the same way to get them started, then topped up by wrist motion \
            after that.
            """,
            systemImage: "battery.75"
        )
    ]

    private static let complicationTopics: [LearnTopic] = [
        LearnTopic(
            slug: "complication-intro",
            category: .complications,
            title: "What Is a Complication?",
            summary: "Any function a watch does beyond simply showing the hours and minutes.",
            body: """
            A "complication" is any feature a watch has beyond displaying the current hour and minute — a \
            date window, a second time zone, a stopwatch function, and so on. The name comes from how much \
            extra mechanical complexity each one adds inside the movement; a simple time-only watch is \
            sometimes called a "time-only" or "simple" watch specifically to contrast it with a \
            "complicated" one.

            Complications range from genuinely useful in daily life (date, GMT) to niche but beloved by \
            collectors for their mechanical artistry (tourbillon, perpetual calendar). The topics below \
            cover the ones most commonly seen, matching the complications you can tag on a watch in your \
            own Vault.
            """,
            systemImage: "puzzlepiece"
        ),
        LearnTopic(
            slug: "complication-date",
            category: .complications,
            title: "Date",
            summary: "A small window showing the current day of the month.",
            body: """
            The most common complication of all: a small window, usually near 3 o'clock, showing the day \
            of the month. Internally it's driven by a date disc that advances once per day, usually with a \
            quick-set function (via a pulled-out crown position) so you can adjust it without spinning the \
            hands all the way around.

            One quirk worth knowing: on many date watches, advancing the date via the crown during the \
            "danger zone" (roughly 9 PM to 3 AM, when the date-change mechanism is mid-cycle) can jam or \
            damage the mechanism — check your watch's specifics before making a habit of setting the date \
            at night.
            """,
            complicationName: "Date",
            systemImage: "calendar"
        ),
        LearnTopic(
            slug: "complication-day-date",
            category: .complications,
            title: "Day-Date",
            summary: "Shows both the day of the week and the date, often spelled out in full.",
            body: """
            A step up from a simple date window, a day-date complication adds the day of the week — often \
            spelled out (e.g. "MONDAY") rather than abbreviated, most famously on Rolex's "Day-Date" model, \
            which is where the generic complication name comes from.

            Because it displays two things instead of one, a day-date mechanism is somewhat more complex \
            internally and usually needs two separate correctors or crown positions to set independently.
            """,
            complicationName: "Day-Date",
            systemImage: "calendar.badge.clock"
        ),
        LearnTopic(
            slug: "complication-chronograph",
            category: .complications,
            title: "Chronograph",
            summary: "A built-in stopwatch, usually started/stopped/reset with pushers beside the crown.",
            body: """
            A chronograph is a stopwatch built into the watch, controlled by two pushers flanking the \
            crown — typically start/stop on top, reset on the bottom. It measures elapsed time separately \
            from the regular time-of-day display, usually via a central chronograph seconds hand plus one \
            or more subdials counting elapsed minutes and hours.

            Combined with a tachymeter bezel or dial scale, a chronograph can also be used to calculate \
            speed over a known distance — the original reason many were built for motorsport and aviation.
            """,
            complicationName: "Chronograph",
            systemImage: "stopwatch"
        ),
        LearnTopic(
            slug: "complication-gmt",
            category: .complications,
            title: "GMT",
            summary: "Tracks a second (or third) time zone with an independently set extra hand.",
            body: """
            A GMT complication adds an extra hand — usually arrow-tipped and a different color — that \
            makes one full rotation every 24 hours instead of 12, pointing to a second time zone on a \
            fixed or rotating 24-hour scale, often marked on the bezel. On a "true" or "caller's" GMT, that \
            hand can be set independently of the main hour hand, so travelers can track home time while \
            adjusting the main display to local time.

            The name comes from Greenwich Mean Time, historically the reference zone pilots and travelers \
            tracked alongside local time.
            """,
            complicationName: "GMT",
            systemImage: "globe"
        ),
        LearnTopic(
            slug: "complication-moonphase",
            category: .complications,
            title: "Moonphase",
            summary: "A rotating disc showing the moon's current phase through a dial cutout.",
            body: """
            A moonphase complication shows the current phase of the moon — new, full, and everything \
            between — through a small dial cutout, typically driven by a slowly rotating disc painted with \
            two moons (so the same disc serves both halves of the lunar cycle).

            Most moonphase discs are geared to a standard 29.5-day lunar cycle and drift out of sync with \
            the actual moon by about a day every couple of years unless corrected; higher-end "astronomical" \
            moonphases use finer gearing to stay accurate for decades between adjustments.
            """,
            complicationName: "Moonphase",
            systemImage: "moon.stars.fill"
        ),
        LearnTopic(
            slug: "complication-power-reserve-indicator",
            category: .complications,
            title: "Power Reserve",
            summary: "A dial indicator showing how much running time is left before the watch stops.",
            body: """
            A power reserve indicator is a small gauge — often on a subdial, sometimes a linear scale — \
            that shows roughly how much stored energy is left in the mainspring before a mechanical or \
            automatic watch runs down and stops. It's most useful right after taking the watch off for a \
            few days, as a quick check of whether it needs winding before you put it back on.

            See Power Reserve & Winding under Movements for what actually determines how long that reserve \
            lasts.
            """,
            complicationName: "Power Reserve",
            systemImage: "gauge.medium"
        ),
        LearnTopic(
            slug: "complication-world-time",
            category: .complications,
            title: "World Time",
            summary: "Displays the current time in every time zone on the dial at once, all the time.",
            body: """
            A world time complication shows all 24 time zones simultaneously, typically via a rotating \
            24-hour ring around the dial's edge paired with a fixed ring of city names — one per time zone \
            — so you can read the current time in, say, Tokyo or London at a glance without resetting \
            anything.

            It's a more elaborate cousin of the simpler GMT complication, trading a single extra hand for a \
            full at-a-glance view of every zone at once.
            """,
            complicationName: "World Time",
            systemImage: "globe.americas.fill"
        ),
        LearnTopic(
            slug: "complication-perpetual-calendar",
            category: .complications,
            title: "Perpetual Calendar",
            summary: "A calendar mechanism that automatically accounts for month lengths and leap years.",
            body: """
            A perpetual calendar displays the date, day, month, and often the leap-year cycle, and — \
            unlike a simple date complication — automatically adjusts for months with 30 vs. 31 days and \
            for February's length in leap years, without needing to be manually corrected at the end of \
            short months. It only needs manual adjustment for the rare exceptions the Gregorian calendar \
            itself carves out (most centuries skip a leap year, which the very fanciest "secular" perpetual \
            calendars also account for).

            It's one of the most prized "grand complications" precisely because building all of that logic \
            mechanically, out of gears and levers rather than a chip, is genuinely difficult.
            """,
            complicationName: "Perpetual Calendar",
            systemImage: "calendar.circle.fill"
        ),
        LearnTopic(
            slug: "complication-tourbillon",
            category: .complications,
            title: "Tourbillon",
            summary: "A rotating cage for the escapement, built to average out the effect of gravity.",
            body: """
            A tourbillon houses the movement's escapement and balance wheel in a cage that continuously \
            rotates, typically once per minute. It was originally invented to average out the timekeeping \
            errors gravity introduces when a pocket watch sits in one orientation for long stretches — by \
            constantly rotating, no single position is favored for long.

            Wristwatches move around constantly compared to pocket watches, so a tourbillon's practical \
            accuracy benefit is far smaller today — it survives mainly as a celebrated feat of miniature \
            mechanical engineering, and its rotating cage is often left visible on the dial as a showpiece.
            """,
            complicationName: "Tourbillon",
            systemImage: "tornado"
        ),
        LearnTopic(
            slug: "complication-alarm",
            category: .complications,
            title: "Alarm",
            summary: "A mechanical or electronic buzzer set to sound at a chosen time.",
            body: """
            An alarm complication lets you set a target time and have the watch produce an audible alert \
            when it arrives — mechanically via a small hammer striking a bell or the case back, or \
            electronically via a piezo buzzer on quartz models. A separate crown, pusher, or rotating disc \
            is usually used to set the alarm time independently of the main hands.

            It was especially popular before phones made a built-in alarm redundant for most people, and \
            remains a favorite among collectors of vintage tool watches for its mechanical novelty.
            """,
            complicationName: "Alarm",
            systemImage: "alarm.fill"
        )
    ]

    private static let materialTopics: [LearnTopic] = [
        LearnTopic(
            slug: "material-stainless-steel",
            category: .materials,
            title: "Stainless Steel",
            summary: "The default case material — durable, affordable, and easy to maintain.",
            body: """
            Stainless steel is by far the most common watch case material: durable, resistant to \
            corrosion, easy to polish, and far cheaper than precious metals. Most steel watch cases use \
            316L, a marine-grade alloy also used in surgical instruments; some higher-end brands use 904L, \
            a more corrosion-resistant (and harder to machine) alloy popularized by Rolex.

            Steel takes a mirror polish well but also shows scratches more visibly than brushed finishes, \
            which is why many cases mix polished and brushed surfaces on different facets.
            """,
            systemImage: "cube.fill"
        ),
        LearnTopic(
            slug: "material-titanium",
            category: .materials,
            title: "Titanium",
            summary: "Lighter than steel, highly corrosion-resistant, and hypoallergenic.",
            body: """
            Titanium is roughly 40% lighter than steel for a similar-sized case, highly resistant to \
            corrosion (including saltwater), and hypoallergenic — a common choice for people whose skin \
            reacts to other metals. It's also harder to machine and polish to a deep shine than steel, so \
            titanium watches are more often finished with a matte or brushed look.

            Its lighter weight is polarizing: some wearers love how unobtrusive it feels on the wrist, \
            others associate a watch's heft with a sense of quality and prefer steel or gold for that reason \
            alone.
            """,
            systemImage: "scalemass"
        ),
        LearnTopic(
            slug: "material-ceramic",
            category: .materials,
            title: "Ceramic",
            summary: "Extremely scratch-resistant, often used for bezels, but brittle under impact.",
            body: """
            Ceramic (specifically zirconium dioxide in most watches) is exceptionally hard and scratch \
            resistant — a ceramic bezel insert will keep its finish for years in conditions that would \
            visibly scuff aluminum or even steel. It also holds color well and doesn't fade in sunlight.

            The tradeoff is brittleness: while nearly impossible to scratch, ceramic can chip or crack from \
            a sharp direct impact in a way a metal case or bezel would just dent instead. It's most often \
            used for bezels and case-back inserts rather than entire cases, though full-ceramic cases exist.
            """,
            systemImage: "hexagon.fill"
        ),
        LearnTopic(
            slug: "material-gold",
            category: .materials,
            title: "Gold",
            summary: "The classic precious-metal case material, in yellow, white, and rose variants.",
            body: """
            Solid gold cases are measured in karats, with 18k (75% gold) the standard for fine watchmaking \
            — pure 24k gold is too soft to hold up as a case. Yellow, white, and rose gold are the same \
            base metal alloyed with different secondary metals (copper for rose gold's warm tone, for \
            instance) to change the color.

            Gold-plated or gold-filled watches are a much cheaper alternative: a thin layer of gold over a \
            base metal, which looks similar new but can wear through over years of use, unlike a solid gold \
            case.
            """,
            systemImage: "medal.fill"
        ),
        LearnTopic(
            slug: "material-crystal-types",
            category: .materials,
            title: "Crystal Types",
            summary: "Sapphire, mineral, and acrylic trade off scratch resistance against cost and repairability.",
            body: """
            Sapphire crystal (synthetic sapphire, not glass) is extremely scratch resistant — only a \
            handful of materials harder than it exist — but can shatter on a sharp impact and is the most \
            expensive to produce. Mineral crystal is ordinary treated glass: cheaper, more shatter \
            resistant than sapphire, but noticeably easier to scratch over time.

            Acrylic (a clear plastic) is the softest of the three and scratches easily, but it's also the \
            most impact-resistant and, unlike the other two, can be buffed back to a clear finish with \
            simple polish rather than replaced — a big reason many vintage watches still use it.
            """,
            systemImage: "sparkles"
        ),
        LearnTopic(
            slug: "material-water-resistance",
            category: .materials,
            title: "Water Resistance Ratings",
            summary: "What 30m, 100m, and 300m ratings actually mean for real-world use.",
            body: """
            Water resistance ratings (e.g. 30m/3 ATM, 100m/10 ATM, 300m/30 ATM) are measured under \
            controlled static pressure in a lab, not literal depth you can safely dive to — movement, \
            temperature changes, and gasket age all reduce the real-world margin. As a rough guide: 30m is \
            splash/rain resistant only, 100m tolerates swimming and snorkeling, and true dive watches start \
            around 200-300m with an ISO 6425 dive certification.

            Because rubber gaskets compress and age over time (even sitting unused), a watch's water \
            resistance can quietly degrade — periodic pressure testing during a routine service is the only \
            reliable way to confirm it still meets its rating.
            """,
            systemImage: "drop.fill"
        )
    ]

    private static let strapTopics: [LearnTopic] = [
        LearnTopic(
            slug: "strap-materials",
            category: .straps,
            title: "Strap Materials",
            summary: "Leather, rubber, NATO, and metal bracelets each suit different situations.",
            body: """
            Leather straps look dressy and break in comfortably over time, but wear out faster and don't \
            tolerate water or heavy sweat well. Rubber (or FKM/silicone) straps are the opposite: built for \
            water and daily abuse, common on dive and sport watches, at some cost to a dressier look. NATO \
            and other fabric straps are cheap, quick to swap, and add a security margin (a broken spring \
            bar on one side still leaves the watch attached via the strap looping under the case), which is \
            part of why they were originally military-issue.

            Metal bracelets (steel, titanium) are the most durable option and usually what a watch ships \
            with from the factory, at the cost of being harder to size and swap than a strap.
            """,
            systemImage: "square.grid.2x2"
        ),
        LearnTopic(
            slug: "strap-clasps",
            category: .straps,
            title: "Clasp Types",
            summary: "Deployant, butterfly, and pin buckles close a strap or bracelet differently.",
            body: """
            A pin buckle works like a belt: a prong through a hole in the strap, simple and low-profile but \
            the strap flexes at a single point over time. A deployant clasp folds flat via a hinged metal \
            bracket sewn or riveted to the strap's underside, reducing wear on the strap material itself \
            and making the watch faster to put on and take off. A butterfly (or "deployment") clasp is a \
            common bracelet variant that folds in two symmetric halves so no exposed pin sticks out to \
            catch on clothing.

            Dive watches often add a clasp extension (sometimes a "wetsuit extension") to fit over a \
            wetsuit sleeve, and some clasps include micro-adjustment holes or a ratchet for fine-tuning fit \
            through the day as the wrist swells slightly with heat or activity.
            """,
            systemImage: "lock.fill"
        ),
        LearnTopic(
            slug: "strap-sizing",
            category: .straps,
            title: "Sizing & Fit",
            summary: "Lug width determines which straps fit; bracelet links can usually be removed to adjust length.",
            body: """
            Every strap has a width matching the gap between a watch's lugs — measured in millimeters, \
            almost always in even numbers (18, 20, 22mm are the most common) — and a strap has to match \
            that measurement exactly (or occasionally taper narrower toward the buckle) to fit properly. \
            This is a separate number from the case diameter, and mixing them up is the most common sizing \
            mistake for newcomers.

            Metal bracelets are typically sized by removing links (with a small pusher tool or pin/screw \
            removal) rather than buying a shorter one outright, so a bracelet that arrives too loose can \
            almost always be adjusted down to fit rather than returned.
            """,
            systemImage: "ruler"
        )
    ]

    private static let maintenanceTopics: [LearnTopic] = [
        LearnTopic(
            slug: "maintenance-servicing",
            category: .maintenance,
            title: "Servicing Basics & Intervals",
            summary: "Mechanical watches need periodic professional service; quartz watches mostly just need a new battery.",
            body: """
            A mechanical or automatic watch is generally recommended for a full service every 3-5 years — \
            the movement is disassembled, cleaned, re-lubricated, and regulated, since old lubricant \
            thickens and internal parts wear very slightly over years of running. Skipping service for too \
            long doesn't usually stop the watch outright, but accuracy drifts and, eventually, wear can \
            cause real damage that costs more to fix than a routine service would have.

            Quartz watches need far less: mainly a battery replacement every 1-2 years (rather than a full \
            movement service), since there's no mainspring or escapement to wear down the way a mechanical \
            movement has.
            """,
            systemImage: "wrench.and.screwdriver.fill"
        ),
        LearnTopic(
            slug: "maintenance-water",
            category: .maintenance,
            title: "Water Resistance Upkeep",
            summary: "Rinse after saltwater exposure, never operate the crown/pushers while wet, and avoid extreme temperature swings.",
            body: """
            Even a well-rated dive watch benefits from a fresh water rinse after exposure to saltwater, \
            chlorine, or sand, since residue left in the case-back threads or bezel can accelerate gasket \
            wear. Never pull the crown out or press chronograph pushers while the watch is wet or \
            underwater — that's exactly when water is most likely to get pushed past the seals.

            Sudden temperature swings (like a hot shower right after cold weather) can also stress gaskets \
            and crystal seals over time. None of this is usually catastrophic on its own, but it adds up — \
            which is part of why water resistance is checked and re-sealed as part of a routine service.
            """,
            systemImage: "water.waves"
        ),
        LearnTopic(
            slug: "maintenance-magnetism",
            category: .maintenance,
            title: "Magnetism",
            summary: "Everyday magnets (phone cases, laptop speakers, bag clasps) can magnetize a mechanical movement and throw off its accuracy.",
            body: """
            Mechanical movements use small steel components (notably the hairspring) that can become \
            magnetized by everyday magnets — phone cases and speaker magnets, laptop and tablet covers, \
            purse and bag clasps, even some kitchen appliances. A magnetized movement doesn't stop, but it \
            typically starts running fast, sometimes losing many minutes a day, because the hairspring's \
            coils cling together instead of expanding and contracting freely.

            The fix is straightforward: a watchmaker (or, for many watches, a simple demagnetizer tool) can \
            demagnetize it in seconds, and accuracy returns to normal immediately with no lasting damage. \
            Some modern movements use silicon hairsprings specifically because they're immune to \
            magnetism entirely.
            """,
            systemImage: "bolt.fill"
        ),
        LearnTopic(
            slug: "maintenance-storage",
            category: .maintenance,
            title: "Storage & Watch Winders",
            summary: "A stopped mechanical watch is fine long-term; a winder just saves you resetting the time and date.",
            body: """
            There's no harm in letting an automatic or mechanical watch simply run down and sit stopped \
            when it's not being worn — mainsprings are designed to sit unwound indefinitely. A watch winder \
            (a motorized box that gently rotates the watch to keep an automatic movement wound) is a \
            convenience, not a necessity: it saves you from resetting the time (and, on some watches, a \
            slow multi-day date correction) every time you pick the watch back up, nothing more.

            Whether stored running or stopped, keeping a watch away from strong magnets, direct sunlight \
            (which can fade dials and straps over years), and extreme humidity will do more for its \
            long-term condition than any winder will.
            """,
            systemImage: "archivebox.fill"
        )
    ]

    private static let buyingTopics: [LearnTopic] = [
        LearnTopic(
            slug: "buying-reference-number",
            category: .buying,
            title: "Reading a Reference Number",
            summary: "A watch's reference number is its unique model identifier — the fastest way to confirm exact specs.",
            body: """
            A reference number is the manufacturer's unique identifier for a specific model and \
            configuration — dial color, bezel material, bracelet vs. strap, and so on often each get their \
            own reference even within the same model line. It's usually printed between the lugs on the \
            case, or on paperwork/warranty cards, and is the single fastest way to confirm you're looking \
            at exactly the watch you think you are rather than a similar-looking variant.

            Searching a reference number is generally more reliable than searching a model name alone, \
              since brands frequently reuse a model name across many distinct references over the decades.
            """,
            systemImage: "number"
        ),
        LearnTopic(
            slug: "buying-used",
            category: .buying,
            title: "Buying Used Safely",
            summary: "Verify the serial number, ask for service history, and buy from reputable sellers.",
            body: """
            When buying a used watch, checking that the serial and reference numbers match what the \
            listing claims (and, ideally, that they're not on any reported stolen-watch registries) is a \
            basic first step. Full box-and-papers (original box, warranty card, purchase receipt) isn't \
            required for a watch to be genuine, but it does support resale value and makes provenance \
            easier to verify later.

            Buying from an authorized dealer, a reputable specialist dealer, or a well-known auction house \
            reduces (though never eliminates) counterfeit risk compared to an anonymous private listing; \
            for anything expensive, having an independent watchmaker inspect it before or shortly after \
            purchase is common practice among experienced collectors.
            """,
            systemImage: "checkmark.seal.fill"
        ),
        LearnTopic(
            slug: "buying-fit",
            category: .buying,
            title: "Fit & Sizing Guidance",
            summary: "Lug-to-lug and case thickness usually matter more to fit than diameter alone.",
            body: """
            Case diameter gets most of the attention in listings, but lug-to-lug length (how far the case \
            extends past the wrist in the 12-to-6 direction) is usually the bigger factor in whether a \
            watch actually fits a given wrist without overhanging the edges. Two watches with the same \
            diameter can wear completely differently if one has noticeably longer lugs.

            Thickness matters too, especially under a shirt cuff, and is easy to overlook when comparing \
            diameters alone. This app's Fit Calculator can help estimate how a given case size and \
            lug-to-lug will actually sit on your own wrist before you buy.
            """,
            systemImage: "ruler.fill"
        )
    ]

    private static let glossaryTopics: [LearnTopic] = [
        LearnTopic(
            slug: "glossary-manufacture",
            category: .glossary,
            title: "Manufacture",
            summary: "A brand that designs and builds its own movements in-house, rather than buying them from a supplier.",
            body: """
            "Manufacture" (used as an adjective, from the French) describes a brand that designs and \
            produces its own movements in-house, rather than sourcing them from a third-party movement \
            maker. Many respected brands do both — some models with an in-house caliber, others built \
            around a bought-in movement — so the term describes a specific model or movement, not \
            necessarily an entire brand.
            """,
            systemImage: "building.2"
        ),
        LearnTopic(
            slug: "glossary-in-house",
            category: .glossary,
            title: "In-House Movement",
            summary: "A movement designed and built by the watch brand itself, as opposed to an outsourced supplier caliber.",
            body: """
            An in-house movement is designed and manufactured by the watch brand itself, as opposed to a \
            movement bought from a specialist supplier like ETA, Sellita, or Miyota and finished/cased by \
            the brand. Neither approach is inherently better — outsourced movements are typically cheaper \
            and very reliably serviceable almost anywhere, while in-house movements let a brand build \
            distinctive features but can mean parts and service are only available through that brand.
            """,
            systemImage: "house.fill"
        ),
        LearnTopic(
            slug: "glossary-homage",
            category: .glossary,
            title: "Homage",
            summary: "A watch that closely borrows the design of a famous model, usually at a much lower price.",
            body: """
            A "homage" watch closely borrows the design language of a famous, usually more expensive model \
            — a dive watch styled after a Submariner, for instance — without using the original brand's name \
            or logo. Opinions in the hobby are split: some see homages as an affordable way to enjoy a \
            beloved design, others see them as too derivative to be worth owning; either way, an homage is \
            legally distinct from a counterfeit, which fraudulently uses the original brand's actual name \
            and trademarks.
            """,
            systemImage: "doc.on.doc"
        ),
        LearnTopic(
            slug: "glossary-lug-to-lug",
            category: .glossary,
            title: "Lug-to-Lug",
            summary: "The distance from the tip of the top lugs to the tip of the bottom lugs.",
            body: """
            Lug-to-lug is the measurement from the outer edge of the 12 o'clock lugs to the outer edge of \
            the 6 o'clock lugs — essentially the watch's total length across the wrist. See Lugs under \
            Watch Anatomy and Fit & Sizing Guidance under Buying & Ownership for why this number matters \
            more to comfortable fit than case diameter alone.
            """,
            systemImage: "arrow.left.and.right"
        ),
        LearnTopic(
            slug: "glossary-beat-rate",
            category: .glossary,
            title: "Beat Rate (VPH / Hz)",
            summary: "How many times per hour a mechanical movement's balance wheel ticks back and forth.",
            body: """
            Beat rate describes how fast a mechanical movement's balance wheel oscillates, usually stated \
            in vibrations per hour (VPH) or Hertz (Hz). A common modern rate is 28,800 VPH (4 Hz); higher \
            rates generally produce a smoother-looking sweep of the seconds hand and can improve shock \
            resistance slightly, at the cost of consuming more of the mainspring's stored energy, which \
            tends to shorten power reserve.
            """,
            systemImage: "waveform.path.ecg"
        ),
        LearnTopic(
            slug: "glossary-jewels",
            category: .glossary,
            title: "Jewels",
            summary: "Synthetic ruby bearings that reduce friction at key pivot points in a mechanical movement.",
            body: """
            "Jewels" in a movement are small synthetic rubies (not decorative — functional) used as \
            low-friction bearings at points where metal parts pivot against each other, reducing wear and \
            improving long-term accuracy. A typical mechanical movement uses somewhere around 17-25 jewels; \
            a higher count isn't automatically better; it mainly reflects how many bearing points the \
            specific movement's design actually has.
            """,
            systemImage: "diamond.fill"
        ),
        LearnTopic(
            slug: "glossary-lume",
            category: .glossary,
            title: "Lume",
            summary: "The luminous material on hands and markers that glows in the dark after charging in light.",
            body: """
            "Lume" is the luminous material applied to hands and hour markers so a watch can be read in the \
            dark. Modern watches almost universally use a non-radioactive photoluminescent compound \
            (commonly Super-LumiNova) that absorbs light and re-emits it slowly, gradually fading over a \
            few hours. Older vintage watches instead used radioactive tritium or radium for a constant, \
            self-powered (rather than charge-and-fade) glow — radium in particular is now considered unsafe \
            and is essentially never used today.
            """,
            systemImage: "light.max"
        ),
        LearnTopic(
            slug: "glossary-chronometer",
            category: .glossary,
            title: "Chronometer (COSC)",
            summary: "A movement independently tested and certified to meet a strict accuracy standard.",
            body: """
            "Chronometer" is a certified accuracy standard, not a complication — a movement earns the title \
            after passing multi-day, multi-position testing by an independent body (in Switzerland, COSC) \
            confirming it keeps time within a tight tolerance, commonly around -4/+6 seconds per day. Not \
            every accurate watch bothers with certification, so its absence doesn't necessarily mean a \
            watch runs less accurately — only that it wasn't submitted for (or didn't pursue) the official \
            test.
            """,
            systemImage: "checkmark.seal"
        ),
        LearnTopic(
            slug: "glossary-metas",
            category: .glossary,
            title: "METAS Certification",
            summary: "A tougher standard than COSC, testing the fully cased watch for accuracy, magnetism resistance, and more.",
            body: """
            METAS (the Swiss Federal Institute of Metrology) certifies watches under a standard developed \
            jointly with Omega, marketed as "Master Chronometer." Where COSC tests only the bare movement \
            for accuracy, METAS tests the fully cased, finished watch — dial, hands, and case included — \
            over eight days in multiple positions and temperatures, checking accuracy (0 to +5 seconds per \
            day, a tighter and differently-shaped tolerance than COSC's), power reserve, and water \
            resistance.

            Its standout requirement is resistance to magnetic fields up to 15,000 gauss, far beyond the \
            everyday magnets described under Magnetism — strong enough that a METAS-certified watch keeps \
            accurate time even after exposure that would noticeably speed up an ordinary mechanical \
            movement. A watch can (and, for Omega, always does) hold both COSC and METAS certification at \
            once, since METAS builds on top of COSC's movement-level test rather than replacing it.
            """,
            systemImage: "checkmark.shield.fill"
        ),
        LearnTopic(
            slug: "glossary-quartz-crisis",
            category: .glossary,
            title: "Quartz Crisis",
            summary: "The 1970s-80s upheaval when cheap, ultra-accurate quartz watches nearly ended Swiss mechanical watchmaking.",
            body: """
            The Quartz Crisis refers to the period from the early 1970s through the 1980s when Japanese \
            quartz watches — far cheaper to produce and dramatically more accurate — flooded the market and \
            devastated the traditional Swiss mechanical watch industry, closing many storied manufacturers \
            and costing tens of thousands of jobs. Swiss watchmaking eventually recovered by repositioning \
            mechanical watches as luxury and craftsmanship objects rather than simply timekeeping tools, \
            which shapes how the mechanical watch market is marketed and priced to this day.
            """,
            systemImage: "chart.line.downtrend.xyaxis"
        )
    ]
}
