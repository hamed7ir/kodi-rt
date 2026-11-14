// kodi-rt Stage 3 device test, C++ libraries (ARM32, static /MT, /EHsc, rt2.4). Self-checking, like s3test-c:
//   CHECK <name> OK|FAIL <details>   ...   ALL PASSED (N checks) | FAILED (k of N checks); exit code = failures.
// Several checks throw inside a library and catch in this program (fmt, nlohmann_json, exiv2): C++ exceptions
// across real library code built by rt2.4, beyond ehtest.
#include <cstdio>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>

#include <fmt/format.h>
#include <spdlog/spdlog.h>
#include <spdlog/sinks/ostream_sink.h>
#include <nlohmann/json.hpp>
#include <tinyxml.h>
#include <tinyxml2.h>
#include <crossguid/guid.hpp>
#include <taglib/tstring.h>
#include <taglib/xiphcomment.h>
#include <exiv2/exiv2.hpp>
#include <flatbuffers/flexbuffers.h>

static int g_checks, g_failed;

static void check(const char *name, bool ok, const std::string &details = {})
{
  g_checks++;
  if (!ok)
    g_failed++;
  std::printf("CHECK %-26s %s %s\n", name, ok ? "OK  " : "FAIL", details.c_str());
  std::fflush(stdout);
}

static void test_fmt()
{
  std::string s = fmt::format("{} {:.2f} {:>4}", 42, 3.14159, "x");
  check("fmt.format", s == "42 3.14    x", s);
  bool caught = false;
  try {
    (void)fmt::format(fmt::runtime("{:d}"), "not a number");
  } catch (const fmt::format_error &e) {
    caught = true;
  }
  check("fmt.throws_format_error", caught);
}

static void test_spdlog()
{
  std::ostringstream oss;
  auto sink = std::make_shared<spdlog::sinks::ostream_sink_mt>(oss);
  auto logger = std::make_shared<spdlog::logger>("kodi-rt", sink);
  logger->set_pattern("%l|%v");
  logger->info("hello {} {}", 42, "ARM32");
  logger->warn("number {:04d}", 7);
  logger->flush();
  std::string out = oss.str();
  bool ok = out.find("info|hello 42 ARM32") != std::string::npos && out.find("warning|number 0007") != std::string::npos;
  check("spdlog.ostream_sink", ok, std::to_string(out.size()) + " bytes");
}

static void test_json()
{
  auto j = nlohmann::json::parse(R"({"name":"Kodi","list":[1,2,3],"nested":{"ok":true}})");
  bool ok = j["name"] == "Kodi" && j["list"][1] == 2 && j["nested"]["ok"] == true;
  check("json.parse", ok, j.dump());
  nlohmann::json back = nlohmann::json::parse(j.dump());
  check("json.roundtrip", back == j);
  bool caught = false;
  try {
    (void)nlohmann::json::parse("{\"broken\": [1, 2");
  } catch (const nlohmann::json::parse_error &e) {
    caught = e.id == 101;
  }
  check("json.throws_parse_error", caught);
}

static void test_xml()
{
  const char *xml = "<settings><setting id=\"a\">Estuary</setting><setting id=\"b\">ARM32</setting></settings>";
  TiXmlDocument d1;
  d1.Parse(xml);
  const TiXmlElement *e1 = d1.RootElement() ? d1.RootElement()->FirstChildElement("setting") : nullptr;
  std::string id1 = e1 && e1->Attribute("id") ? e1->Attribute("id") : "";
  check("tinyxml.parse", !d1.Error() && e1 && id1 == "a" && std::string(e1->GetText()) == "Estuary");
  tinyxml2::XMLDocument d2;
  bool ok = d2.Parse(xml) == tinyxml2::XML_SUCCESS;
  const tinyxml2::XMLElement *e2 = ok ? d2.RootElement()->FirstChildElement("setting")->NextSiblingElement() : nullptr;
  check("tinyxml2.parse", ok && e2 && std::string(e2->GetText()) == "ARM32");
}

static void test_guid()
{
  xg::Guid a = xg::newGuid(), b = xg::newGuid();
  std::string s = a.str();
  check("crossguid.new", a.isValid() && s.size() == 36 && s[8] == '-' && a != b, s);
}

static void test_taglib()
{
  TagLib::Ogg::XiphComment c;
  c.setTitle(TagLib::String("Kodi on RT", TagLib::String::UTF8));
  c.setArtist(TagLib::String("Surface", TagLib::String::UTF8));
  TagLib::ByteVector data = c.render(false);
  TagLib::Ogg::XiphComment back(data);
  bool ok = back.title().to8Bit(true) == "Kodi on RT" && back.artist().to8Bit(true) == "Surface";
  check("taglib.xiph_roundtrip", ok, std::to_string(data.size()) + " bytes");
}

static void test_exiv2()
{
  check("exiv2.version", Exiv2::versionString() == "0.28.8", Exiv2::versionString());
  Exiv2::ExifData ed;
  ed["Exif.Image.Make"] = "Kodi";
  ed["Exif.Image.Model"] = "Surface RT";
  Exiv2::Blob blob;
  Exiv2::ExifParser::encode(blob, Exiv2::littleEndian, ed);
  Exiv2::ExifData back;
  Exiv2::ExifParser::decode(back, blob.data(), blob.size());
  auto it = back.findKey(Exiv2::ExifKey("Exif.Image.Model"));
  check("exiv2.exif_roundtrip", it != back.end() && it->toString() == "Surface RT", std::to_string(blob.size()) + " bytes");
  bool caught = false;
  try {
    Exiv2::ExifKey bad("Exif.NoSuchGroup.NoSuchTag");
  } catch (const Exiv2::Error &e) {
    caught = true;
  }
  check("exiv2.throws_error", caught);
}

static void test_flexbuffers()
{
  flexbuffers::Builder fbb;
  fbb.Map([&]() {
    fbb.Int("width", 1366);
    fbb.String("device", "Surface RT");
  });
  fbb.Finish();
  auto m = flexbuffers::GetRoot(fbb.GetBuffer()).AsMap();
  check("flatbuffers.flexbuffers", m["width"].AsInt64() == 1366 && m["device"].AsString().str() == "Surface RT",
        std::to_string(fbb.GetBuffer().size()) + " bytes");
}

int main()
{
  std::printf("kodi-rt stage 3 C++ library test\n");
  try {
    test_fmt();
    test_spdlog();
    test_json();
    test_xml();
    test_guid();
    test_taglib();
    test_exiv2();
    test_flexbuffers();
  } catch (const std::exception &e) {
    check("unexpected_exception", false, e.what());
  } catch (...) {
    check("unexpected_exception", false, "unknown");
  }
  if (g_failed == 0)
    std::printf("ALL PASSED (%d checks)\n", g_checks);
  else
    std::printf("FAILED (%d of %d checks)\n", g_failed, g_checks);
  return g_failed;
}
