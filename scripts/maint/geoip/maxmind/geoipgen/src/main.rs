use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::net::IpAddr;
use ipnetwork::IpNetwork;

fn ipv4_to_u32(ip: std::net::Ipv4Addr) -> u32 {
    u32::from(ip)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let loc_file = BufReader::new(File::open("geoip-csv/GeoLite2-Country-Locations-en.csv")?);
    let mut id_map = HashMap::new();

    for line in loc_file.lines().skip(1) {
        let line = line?;
        let fields: Vec<&str> = line.split(',').collect();
        if fields.len() > 5 && !fields[0].is_empty() && !fields[4].is_empty() {
            id_map.insert(fields[0].to_string(), fields[4].to_string()); // geoname_id -> iso_code
        }
    }

    let mut geoip = File::create("geoip")?;
    let v4_file = BufReader::new(File::open("geoip-csv/GeoLite2-Country-Blocks-IPv4.csv")?);
    for line in v4_file.lines().skip(1) {
        let line = line?;
        let fields: Vec<&str> = line.split(',').collect();
        if fields.len() > 1 {
            if let Some(iso) = id_map.get(fields[1]) {
                if let Ok(IpNetwork::V4(net)) = fields[0].parse() {
                    let start = ipv4_to_u32(net.network());
                    let end = ipv4_to_u32(net.broadcast());
                    writeln!(geoip, "{},{},{}", start, end, iso)?;
                }
            }
        }
    }

    let mut geoip6 = File::create("geoip6")?;
    let v6_file = BufReader::new(File::open("geoip-csv/GeoLite2-Country-Blocks-IPv6.csv")?);
    for line in v6_file.lines().skip(1) {
        let line = line?;
        let fields: Vec<&str> = line.split(',').collect();
        if fields.len() > 1 {
            if let Some(iso) = id_map.get(fields[1]) {
                if let Ok(IpNetwork::V6(net)) = fields[0].parse() {
                    let start = net.network();
                    let end = net.broadcast();
                    writeln!(geoip6, "{},{},{}", start, end, iso)?;
                }
            }
        }
    }

    println!("Done: wrote geoip and geoip6");
    Ok(())
}
