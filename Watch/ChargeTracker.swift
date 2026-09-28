import Foundation

/// 알림 조건 판단 + 충전 속도 추정 + 다음 refresh 시각 계산
enum ChargeTracker {
    struct Decision {
        var shouldAlert = false
        var resetReason: String?
    }

    /// 충전 1회당 1번만 알림. 분리되거나 (임계값 - 5%) 미만이면 상태 초기화.
    static func evaluate(_ reading: BatteryReading, threshold: Int) -> Decision {
        var decision = Decision()
        guard let level = reading.level else { return decision }

        if reading.state == .unplugged {
            if SharedDefaults.alertedForCurrentCharge { decision.resetReason = "상태 초기화: 충전기 분리" }
            SharedDefaults.alertedForCurrentCharge = false
            SharedDefaults.chargeSamples = []
        } else if level < threshold - AppConstants.resetMargin {
            if SharedDefaults.alertedForCurrentCharge {
                decision.resetReason = "상태 초기화: \(threshold - AppConstants.resetMargin)% 미만"
            }
            SharedDefaults.alertedForCurrentCharge = false
        }

        if reading.state.isOnCharger {
            appendSample(BatterySample(date: reading.date, level: level))
        }

        if reading.state.isOnCharger, level >= threshold, !SharedDefaults.alertedForCurrentCharge {
            SharedDefaults.alertedForCurrentCharge = true
            decision.shouldAlert = true
        }
        return decision
    }

    private static func appendSample(_ sample: BatterySample) {
        var samples = SharedDefaults.chargeSamples
        // 배터리가 오히려 줄었으면(충전 재시작 등) 이전 샘플은 버린다
        if let last = samples.last, sample.level < last.level { samples = [] }
        samples.append(sample)
        let cutoff = sample.date.addingTimeInterval(-3 * 3600)
        samples = Array(samples.filter { $0.date >= cutoff }.suffix(30))
        SharedDefaults.chargeSamples = samples
    }

    /// 최근 2시간 샘플로 충전 속도(%/분) 추정. 표본 부족 시 nil.
    static func estimatedRatePerMinute(now: Date = Date()) -> Double? {
        let recent = SharedDefaults.chargeSamples.filter { now.timeIntervalSince($0.date) <= 2 * 3600 }
        guard let first = recent.first, let last = recent.last else { return nil }
        let minutes = last.date.timeIntervalSince(first.date) / 60
        let delta = Double(last.level - first.level)
        guard minutes >= 3, delta >= 1 else { return nil }
        return delta / minutes
    }

    /// 다음 백그라운드 refresh 희망 시각과 그 이유
    static func nextRefresh(after reading: BatteryReading, threshold: Int, now: Date = Date()) -> (date: Date, reason: String) {
        let fallback = (now.addingTimeInterval(AppConstants.defaultRefreshInterval), "기본 15분")
        guard reading.state.isOnCharger,
              !SharedDefaults.alertedForCurrentCharge,
              let level = reading.level, level < threshold
        else { return fallback }
        guard let rate = estimatedRatePerMinute(now: now), rate > 0.01 else {
            return (fallback.0, "기본 15분 (충전 속도 추정 불가)")
        }
        let etaMinutes = Double(threshold - level) / rate
        // 도달 예상 시각 + 1분. 너무 이르거나 늦지 않게 5~60분으로 제한
        let delay = min(max(etaMinutes + 1, 5), 60)
        let reason = String(format: "%.2f%%/분, 도달 예상 %.0f분 후", rate, etaMinutes)
        return (now.addingTimeInterval(delay * 60), reason)
    }
}
