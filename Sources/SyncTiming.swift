import Foundation

/// NTP-style four monotonic timestamps; peer clock minus local clock.
/// Path asymmetry remains unknowable without an external shared clock.
struct SyncClockSample {
    let rtt:Double,offset:Double,at:Double
    init?(sent:Double,received:Double,replied:Double,arrived:Double) {
        let rtt=(arrived-sent)-(replied-received)
        guard [sent,received,replied,arrived].allSatisfy({$0.isFinite && $0>=0}),arrived>=sent,replied>=received,rtt>=0,rtt<2 else {return nil}
        let delta=((received-sent)+(replied-arrived))/2
        guard delta.isFinite else {return nil}
        self.rtt=rtt;offset=delta;at=arrived
    }
}
struct SyncClockEstimate {
    private(set) var samples:[SyncClockSample]=[]
    mutating func add(_ sample:SyncClockSample) {samples.append(sample);if samples.count>24 {samples.removeFirst(samples.count-24)}}
    var best:[SyncClockSample] {Array(samples.sorted {$0.rtt<$1.rtt}.prefix(8))}
    var offset:Double {let values=best.map(\.offset).sorted();return values.isEmpty ? 0:values[values.count/2]}
    var rtt:Double {best.isEmpty ? 0:best.map(\.rtt).reduce(0,+)/Double(best.count)}
    var jitter:Double {guard let low=samples.map(\.rtt).min(),let high=samples.map(\.rtt).max() else {return 0};return high-low}
    func ready(at now:Double)->Bool {samples.count>=4 && now-(samples.last?.at ?? 0)<4 && rtt<0.15 && jitter<0.08}
}
struct SyncProbe:Codable {
    let id:UUID
    let sent:Double
    var received:Double?=nil
    var replied:Double?=nil
    var driftMS:Double?=nil
    var status:String?=nil
    var valid:Bool {[sent,received ?? 0,replied ?? 0,driftMS ?? 0].allSatisfy(\.isFinite) && sent>=0 && (received.map {$0>=0} ?? true) && (replied.map {$0>=0} ?? true) && abs(driftMS ?? 0)<604800000 && (status?.utf8.count ?? 0)<100}
}
