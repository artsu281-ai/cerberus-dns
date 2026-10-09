import SwiftUI

// MARK: - Custom Vector Country Flag Component
struct CustomCountryFlag: View {
    let code: String
    var width: CGFloat = 22
    var height: CGFloat = 15
    
    var body: some View {
        let key = normalizeCode(code)
        
        ZStack {
            switch key {
            case "NL":
                netherlandsFlag
            case "DE":
                germanyFlag
            case "FI":
                finlandFlag
            case "SE":
                swedenFlag
            case "US":
                usaFlag
            case "GB":
                ukFlag
            case "FR":
                franceFlag
            case "PL":
                polandFlag
            case "JP":
                japanFlag
            case "TR":
                turkeyFlag
            case "RU":
                russiaFlag
            case "CH":
                switzerlandFlag
            case "KG":
                kyrgyzstanFlag
            case "WARP":
                warpBadge
            case "LOCAL":
                localMacBadge
            default:
                globalAnycastBadge
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: max(2.5, height * 0.2), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: max(2.5, height * 0.2), style: .continuous)
                .stroke(Color.primary.opacity(0.18), lineWidth: 0.75)
        )
    }
    
    private func normalizeCode(_ raw: String) -> String {
        let clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "ky" { return "KG" }   // код языка интерфейса, не страны
        if clean.contains("nl") || clean.contains("netherland") || clean.contains("amsterdam") { return "NL" }
        if clean.contains("de") || clean.contains("germany") || clean.contains("frankfurt") { return "DE" }
        if clean.contains("fi") || clean.contains("finland") || clean.contains("helsinki") { return "FI" }
        if clean.contains("se") || clean.contains("sweden") || clean.contains("stockholm") { return "SE" }
        if clean.contains("us") || clean.contains("usa") || clean.contains("newyork") || clean.contains("america") { return "US" }
        if clean.contains("gb") || clean.contains("uk") || clean.contains("london") || clean.contains("britain") { return "GB" }
        if clean.contains("fr") || clean.contains("france") || clean.contains("paris") { return "FR" }
        if clean.contains("pl") || clean.contains("poland") || clean.contains("warsaw") { return "PL" }
        if clean.contains("jp") || clean.contains("japan") || clean.contains("tokyo") { return "JP" }
        if clean.contains("tr") || clean.contains("turkey") || clean.contains("istanbul") { return "TR" }
        if clean.contains("ru") || clean.contains("russia") || clean.contains("россия") { return "RU" }
        if clean.contains("ch") || clean.contains("swiss") || clean.contains("switzerland") || clean.contains("quad9") { return "CH" }
        if clean.contains("kg") || clean.contains("kyrgyz") || clean.contains("кыргыз") { return "KG" }
        if clean.contains("warp") || clean.contains("cloudflare") { return "WARP" }
        if clean.contains("local") || clean.contains("dnsmasq") || clean.contains("v2ray") || clean.contains("127.0.0.1") { return "LOCAL" }
        return "WW"
    }
    
    // MARK: - Netherlands (🇳🇱)
    private var netherlandsFlag: some View {
        let stripeH = height / 3.0
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.68, green: 0.10, blue: 0.15))
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 0.12, green: 0.30, blue: 0.60))
                .frame(width: width, height: stripeH)
        }
    }
    
    // MARK: - Germany (🇩🇪)
    private var germanyFlag: some View {
        let stripeH = height / 3.0
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.10, green: 0.10, blue: 0.10))
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 0.86, green: 0.0, blue: 0.0))
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 1.0, green: 0.80, blue: 0.0))
                .frame(width: width, height: stripeH)
        }
    }
    
    // MARK: - Finland (🇫🇮)
    private var finlandFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: height)
            // Horizontal cross bar
            Rectangle()
                .fill(Color(red: 0.0, green: 0.22, blue: 0.55))
                .frame(width: width, height: height * 0.32)
            // Vertical cross bar
            HStack(spacing: 0) {
                Spacer().frame(width: width * 0.28)
                Rectangle()
                    .fill(Color(red: 0.0, green: 0.22, blue: 0.55))
                    .frame(width: width * 0.24, height: height)
                Spacer()
            }
        }
    }
    
    // MARK: - Sweden (🇸🇪)
    private var swedenFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.42, blue: 0.70))
                .frame(width: width, height: height)
            // Horizontal cross bar
            Rectangle()
                .fill(Color(red: 0.99, green: 0.80, blue: 0.0))
                .frame(width: width, height: height * 0.30)
            // Vertical cross bar
            HStack(spacing: 0) {
                Spacer().frame(width: width * 0.28)
                Rectangle()
                    .fill(Color(red: 0.99, green: 0.80, blue: 0.0))
                    .frame(width: width * 0.22, height: height)
                Spacer()
            }
        }
    }
    
    // MARK: - USA (🇺🇸)
    private var usaFlag: some View {
        let stripeH = height / 7.0
        return ZStack(alignment: .topLeading) {
            // 7 Stripes
            VStack(spacing: 0) {
                ForEach(0..<7) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color(red: 0.75, green: 0.14, blue: 0.20) : Color.white)
                        .frame(width: width, height: stripeH)
                }
            }
            // Canton
            Rectangle()
                .fill(Color(red: 0.12, green: 0.20, blue: 0.45))
                .frame(width: width * 0.45, height: height * 0.57)
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: max(4, height * 0.28)))
                        .foregroundColor(.white)
                )
        }
    }
    
    // MARK: - Russia (🇷🇺)
    private var russiaFlag: some View {
        let stripeH = height / 3.0
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 0.0, green: 0.32, blue: 0.65))
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 0.84, green: 0.14, blue: 0.13))
                .frame(width: width, height: stripeH)
        }
    }
    
    // MARK: - Switzerland (🇨🇭)
    private var switzerlandFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.85, green: 0.10, blue: 0.12))
                .frame(width: width, height: height)
            Rectangle()
                .fill(Color.white)
                .frame(width: width * 0.54, height: height * 0.26)
            Rectangle()
                .fill(Color.white)
                .frame(width: width * 0.20, height: height * 0.65)
        }
    }
    
    // MARK: - Kyrgyzstan (🇰🇬)
    private var kyrgyzstanFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.88, green: 0.15, blue: 0.15))
                .frame(width: width, height: height)
            Circle()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.0))
                .frame(width: height * 0.55, height: height * 0.55)
            Circle()
                .stroke(Color(red: 0.88, green: 0.15, blue: 0.15), lineWidth: 1)
                .frame(width: height * 0.35, height: height * 0.35)
        }
    }
    
    // MARK: - United Kingdom (🇬🇧)
    private var ukFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.01, green: 0.13, blue: 0.45))
                .frame(width: width, height: height)
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: height * 0.34)
            Rectangle()
                .fill(Color.white)
                .frame(width: width * 0.28, height: height)
            Rectangle()
                .fill(Color(red: 0.80, green: 0.08, blue: 0.12))
                .frame(width: width, height: height * 0.20)
            Rectangle()
                .fill(Color(red: 0.80, green: 0.08, blue: 0.12))
                .frame(width: width * 0.16, height: height)
        }
    }
    
    // MARK: - France (🇫🇷)
    private var franceFlag: some View {
        let stripeW = width / 3.0
        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.15, blue: 0.55))
                .frame(width: stripeW, height: height)
            Rectangle()
                .fill(Color.white)
                .frame(width: stripeW, height: height)
            Rectangle()
                .fill(Color(red: 0.90, green: 0.10, blue: 0.15))
                .frame(width: stripeW, height: height)
        }
    }
    
    // MARK: - Poland (🇵🇱)
    private var polandFlag: some View {
        let stripeH = height / 2.0
        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: stripeH)
            Rectangle()
                .fill(Color(red: 0.86, green: 0.12, blue: 0.25))
                .frame(width: width, height: stripeH)
        }
    }
    
    // MARK: - Japan (🇯🇵)
    private var japanFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: width, height: height)
            Circle()
                .fill(Color(red: 0.75, green: 0.0, blue: 0.10))
                .frame(width: height * 0.58, height: height * 0.58)
        }
    }
    
    // MARK: - Turkey (🇹🇷)
    private var turkeyFlag: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.88, green: 0.05, blue: 0.10))
                .frame(width: width, height: height)
            Circle()
                .fill(Color.white)
                .frame(width: height * 0.52, height: height * 0.52)
                .offset(x: -width * 0.06)
            Circle()
                .fill(Color(red: 0.88, green: 0.05, blue: 0.10))
                .frame(width: height * 0.42, height: height * 0.42)
                .offset(x: -width * 0.02)
            Image(systemName: "star.fill")
                .font(.system(size: max(4, height * 0.28)))
                .foregroundColor(.white)
                .offset(x: width * 0.14)
        }
    }
    
    // MARK: - Cloudflare WARP Edge Badge (⚡️)
    private var warpBadge: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.50, blue: 0.12), Color(red: 0.90, green: 0.30, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: max(6, height * 0.62), weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Local Mac Badge (💻)
    private var localMacBadge: some View {
        ZStack {
            Color(red: 0.15, green: 0.16, blue: 0.20)
                .frame(width: width, height: height)
            Image(systemName: "cpu")
                .font(.system(size: max(6, height * 0.6), weight: .semibold))
                .foregroundColor(Color.cyan)
        }
    }
    
    // MARK: - Global Anycast Badge (🌐)
    private var globalAnycastBadge: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.50, blue: 0.95), Color(red: 0.05, green: 0.35, blue: 0.80)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)
            
            Image(systemName: "globe.americas.fill")
                .font(.system(size: max(6, height * 0.62)))
                .foregroundColor(.white)
        }
    }
}
