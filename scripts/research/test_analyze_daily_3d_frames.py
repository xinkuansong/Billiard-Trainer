"""Synthetic fixtures using inspected xctrace schemas; no device claims."""

import hashlib
import copy
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from analyze_daily_3d_frames import COMMAND_BUFFER_ROOT_ENCODER, EvidenceError, Table, analyze, attributed_buffers


MARKER = "QiuJi.DailyClearance3D.Scene"
PID = 123


def write_table(path, schema, columns, rows):
    root = ET.Element("trace-query-result")
    node = ET.SubElement(root, "node")
    sc = ET.SubElement(node, "schema", name=schema)
    for name in columns:
        col = ET.SubElement(sc, "col")
        ET.SubElement(col, "mnemonic").text = name
    for values in rows:
        row = ET.SubElement(node, "row")
        for key, value in zip(columns, values):
            if isinstance(value, ET.Element):
                row.append(copy.deepcopy(value))
            elif key == "process":
                proc = ET.SubElement(row, "process")
                ET.SubElement(proc, "pid").text = str(value)
            else:
                ET.SubElement(row, "value").text = str(value)
    ET.ElementTree(root).write(path)


class PresentationEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.paths = {name: self.folder / f"{name}.xml"
                      for name in ("labels", "encoders", "requests", "swaps")}
        self.manifest = self.folder / "phases.json"
        self.raw_schema = False
        self.source = self.folder / "signposts.xml"
        self.source.write_text("synthetic test phase source; not actual device evidence")
        self.data = {
            "version": 1, "clock": "trace-relative-ns", "pid": PID,
            "evidence_scope": "live", "encoder_label": MARKER,
            "phase_source": {"path": self.source.name,
                             "sha256": hashlib.sha256(self.source.read_bytes()).hexdigest()},
            "phases": [
                {"name": "idle", "instance": "idle-1", "start_ns": 200_000_000, "end_ns": 800_000_000},
                {"name": "aim", "instance": "aim-1", "start_ns": 1_000_000_000, "end_ns": 2_200_000_000},
                {"name": "orbit", "instance": "orbit-1", "start_ns": 3_000_000_000, "end_ns": 4_200_000_000},
                {"name": "break", "instance": "break-1", "start_ns": 5_000_000_000, "end_ns": 6_200_000_000},
            ],
        }
        self.generate()

    def generate(self, scene_period=16_666_667, ui_period=None, marker_pid=PID):
        labels, encoders, requests, swaps = [], [], [], []
        streams = [(scene_period, MARKER, 0, marker_pid)]
        if ui_period:
            streams.append((ui_period, "root-layer", 1_000_000, PID))
        for period, label, offset, owner in streams:
            for i, present in enumerate(range(20_000_000, 7_000_000_000, period)):
                present += offset
                cb = offset + i + 100
                encoder = offset + i + 10_000
                surface = offset + i % 3 + 200
                labels.append([present - 6_000_000, encoder, label, owner])
                encoders.append([present - 8_000_000, 5_000_000, owner, encoder, cb])
                requests.append([present - 5_000_000, cb, surface, owner])
                swaps.append([present, surface, cb, "Built-In Display", 20])
        self.rows = {"labels": labels, "encoders": encoders, "requests": requests, "swaps": swaps}
        self.write()

    def write(self):
        definitions = {
            "labels": ("metal-object-label", ["timestamp", "object-id", "label", "pid"]),
            "encoders": ("metal-application-intervals", ["start", "duration", "process", "encoder-id", "cmdbuffer-id"]),
            "requests": ("ca-client-present-request", ["timestamp", "cmdbuffer-id", "surface-id", "process"]),
            "swaps": ("display-surface-swap", ["timestamp", "surface-id", "swap-id", "display-name", "framebuffer-index"]),
        }
        if self.raw_schema:
            definitions["labels"][1].append("object-type")
            definitions["encoders"][1].extend(["event-type", "event-label"])
        for key, (schema, columns) in definitions.items():
            write_table(self.paths[key], schema, columns, self.rows[key])
        self.manifest.write_text(json.dumps(self.data))

    def run_analysis(self):
        return analyze(self.manifest, **{f"{k}_path": p for k, p in self.paths.items()})

    def make_raw_fixture(self):
        """Observed raw shape: label at CB root start, nested/ref event label.

        The synthetic times are independent of the real phone trace. CB roots
        and child encoders are separate Encoding rows; requests follow encoding.
        """
        self.raw_schema = True
        originals = list(self.rows["encoders"])
        self.raw_roots, self.raw_children = [], []
        labels = {(r[3], r[1]): r for r in self.rows["labels"]}
        process_ids, label_ids = {}, {}

        def process(owner):
            if owner in process_ids:
                return ET.Element("process", ref=process_ids[owner])
            key = f"process-{owner}"
            process_ids[owner] = key
            element = ET.Element("process", id=key)
            ET.SubElement(element, "pid").text = str(owner)
            return element

        def event_label(name, owner, shared=False):
            element = ET.Element("formatted-label", fmt=f"{name} (thread pid {owner})")
            if shared and name in label_ids:
                ET.SubElement(element, "metal-object-label", ref=label_ids[name])
            else:
                label = ET.SubElement(element, "metal-object-label", fmt=name)
                label.text = name
                if shared:
                    label_ids[name] = f"label-{len(label_ids)}"
                    label.set("id", label_ids[name])
            thread = ET.SubElement(element, "thread")
            thread.append(process(owner))
            return element

        for start, duration, owner, encoder, cb in originals:
            root_start, root_duration = start - 1_000_000, duration + 2_000_000
            label_row = labels[(owner, encoder)]
            label_row[0] = root_start
            label_row.append(11)
            root_process = process(owner)
            root_label = event_label("Command Buffer 0", owner)
            self.raw_roots.append([root_start, root_duration, root_process,
                                   COMMAND_BUFFER_ROOT_ENCODER, cb,
                                   "Encoding", root_label])
            self.raw_children.append([start, duration, process(owner), encoder, cb,
                                      "Encoding", event_label(label_row[2], owner, shared=True)])
        self.rows["encoders"] = [r for pair in zip(self.raw_roots, self.raw_children) for r in pair]
        for request in self.rows["requests"]:
            request[0] += 4_000_000  # After CB encoding and before the synthetic swap.
        self.write()

    def raw_attribution(self):
        return attributed_buffers(
            Table(self.paths["labels"], "metal-object-label", set()),
            Table(self.paths["encoders"], "metal-application-intervals", set()), PID, MARKER)

    def test_raw_prestart_markers_require_exact_structured_encoder_labels(self):
        self.make_raw_fixture()
        self.assertLess(self.rows["labels"][0][0], self.raw_children[0][0])
        buffers, matches = self.raw_attribution()
        self.assertEqual(matches, len(self.raw_children))
        self.assertEqual(len(buffers), len(self.raw_children))
        result, status = self.run_analysis()
        self.assertEqual(result["attribution"]["marked_encoders"], matches)
        self.assertEqual(status, 2)
        self.assertFalse(result["frame_interval_gate_passed"])
        self.assertFalse(result["overall_goal_accepted"])

    def test_raw_formatted_text_cannot_replace_exact_nested_marker(self):
        self.make_raw_fixture()
        label = self.raw_children[0][-1].find("metal-object-label")
        label.text = "Render Command 2"
        # fmt still contains the exact marker, and other rows reference this label.
        self.write()
        with self.assertRaisesRegex(EvidenceError, "exact attribution"):
            self.raw_attribution()

    def test_raw_marker_text_in_narrative_is_not_a_metal_object_label(self):
        self.make_raw_fixture()
        self.raw_children[0][-1].find("metal-object-label").tag = "narrative-text"
        self.write()
        with self.assertRaisesRegex(EvidenceError, "exact attribution"):
            self.raw_attribution()

    def test_raw_marker_from_other_pid_cannot_attribute_encoders(self):
        self.make_raw_fixture()
        for row in self.rows["labels"]:
            row[3] = PID + 1
        self.write()
        with self.assertRaisesRegex(EvidenceError, "requested PID"):
            self.raw_attribution()

    def test_raw_nested_thread_pid_conflict_is_rejected(self):
        self.make_raw_fixture()
        thread = self.raw_children[0][-1].find("thread")
        thread.clear()
        ET.SubElement(ET.SubElement(thread, "process"), "pid").text = str(PID + 1)
        self.write()
        with self.assertRaisesRegex(EvidenceError, "conflicting PID"):
            self.raw_attribution()

    def test_raw_stale_marker_outside_unique_buffer_root_is_rejected(self):
        self.make_raw_fixture()
        for row in self.rows["labels"]:
            row[0] -= 1  # No arbitrary millisecond tolerance at the root boundary.
        self.write()
        with self.assertRaisesRegex(EvidenceError, "exact attribution"):
            self.raw_attribution()

    def test_raw_queue_marker_cannot_stand_in_for_encoder_marker(self):
        self.make_raw_fixture()
        self.rows["labels"][0][-1] = 5
        self.write()
        with self.assertRaisesRegex(EvidenceError, "render encoder object"):
            self.raw_attribution()

    def test_raw_encoder_relabel_inside_buffer_root_is_ambiguous(self):
        self.make_raw_fixture()
        changed = list(self.rows["labels"][0])
        changed[0] += 1
        changed[2] = "root-layer"
        self.rows["labels"].append(changed)
        self.write()
        with self.assertRaisesRegex(EvidenceError, "relabeling"):
            self.raw_attribution()

    def test_raw_reused_encoder_id_cannot_borrow_first_interval_marker(self):
        self.make_raw_fixture()
        self.raw_children[1][3] = self.raw_children[0][3]
        self.write()
        with self.assertRaisesRegex(EvidenceError, "Reused encoder"):
            self.raw_attribution()

    def test_raw_reused_command_buffer_root_is_rejected(self):
        self.make_raw_fixture()
        self.raw_roots[1][4] = self.raw_roots[0][4]
        self.raw_children[1][4] = self.raw_roots[0][4]
        self.write()
        with self.assertRaisesRegex(EvidenceError, "reused command-buffer root"):
            self.raw_attribution()

    def test_raw_child_interval_outside_parent_is_rejected(self):
        self.make_raw_fixture()
        self.raw_children[0][1] += 2_000_000
        self.write()
        with self.assertRaisesRegex(EvidenceError, "outside its command-buffer root"):
            self.raw_attribution()

    def test_raw_second_present_cannot_reuse_marked_buffer_identity(self):
        self.make_raw_fixture()
        request = list(self.rows["requests"][0])
        request[0] += 100_000_000
        self.rows["requests"].append(request)
        self.write()
        with self.assertRaisesRegex(EvidenceError, "Reused marked command-buffer"):
            self.run_analysis()

    def test_raw_present_before_root_completion_is_rejected(self):
        self.make_raw_fixture()
        self.rows["requests"][0][0] = self.raw_roots[0][0] + 1
        self.write()
        with self.assertRaisesRegex(EvidenceError, "precedes marked command-buffer"):
            self.run_analysis()

    def test_smooth_candidate_60hz_cannot_pass_without_presentation_identity(self):
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertFalse(result["evidence_valid"])
        self.assertFalse(result["presentation_attribution_complete"])
        self.assertFalse(result["frame_interval_gate_passed"])
        self.assertTrue(result["candidate_statistics_only"])
        self.assertFalse(result["overall_goal_accepted"])
        self.assertEqual(result["phases"][0]["interval_gate"], "not_applicable_intentional_idle")
        for phase in result["phases"][1:]:
            self.assertTrue(phase["candidate_interval_threshold_met"])
            self.assertTrue(phase["candidate_boundary_threshold_met"])
            self.assertEqual(phase["interval_gate"], "unverified_presentation_identity")
            self.assertEqual(phase["boundary_20ms_check"], "unverified_presentation_identity")
            self.assertIn("candidate_presented_frames", phase)
            self.assertNotIn("presented_frames", phase)
        self.assertNotIn("presentations", result)
        self.assertNotIn("active_fraction_le_20ms", result)
        self.assertNotIn("attributed_display_swaps", result["attribution"])
        self.assertEqual(len(result["candidate_presentations"]),
                         result["attribution"]["candidate_display_swaps"])

    def test_swiftui_60hz_cannot_hide_scenekit_30hz(self):
        self.generate(scene_period=33_333_333, ui_period=16_666_667)
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertFalse(result["frame_interval_gate_passed"])
        self.assertEqual(result["candidate_active_fraction_le_20ms"], 0)
        self.assertLess(result["attribution"]["candidate_display_swaps"], 220)

    def test_idle_hold_is_not_counted_as_active_stutter(self):
        for key, timestamp_index in [("labels", 0), ("encoders", 0), ("requests", 0), ("swaps", 0)]:
            self.rows[key] = [r for r in self.rows[key] if not 200_000_000 <= r[timestamp_index] <= 800_000_000]
        self.write()
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertEqual(result["phases"][0]["candidate_presented_frames"], 0)

    def test_wrong_pid_rejected(self):
        self.data["pid"] = 999
        self.write()
        with self.assertRaisesRegex(EvidenceError, "requested PID"):
            self.run_analysis()

    def test_historical_trace_cannot_pass_live_gate(self):
        self.data["evidence_scope"] = "historical_schema_research"
        self.write()
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertFalse(result["frame_interval_gate_passed"])

    def test_empty_table_rejected(self):
        self.rows["swaps"] = []
        self.write()
        with self.assertRaisesRegex(EvidenceError, "no samples"):
            self.run_analysis()

    def test_missing_phase_rejected(self):
        self.data["phases"] = self.data["phases"][:-1]
        self.write()
        with self.assertRaisesRegex(EvidenceError, "Missing required phases"):
            self.run_analysis()

    def test_overlap_rejected(self):
        self.data["phases"][1]["start_ns"] = 700_000_000
        self.write()
        with self.assertRaisesRegex(EvidenceError, "overlap"):
            self.run_analysis()

    def test_truncated_retention_rejected(self):
        self.rows["swaps"] = [r for r in self.rows["swaps"] if r[0] < 5_500_000_000]
        self.write()
        with self.assertRaisesRegex(EvidenceError, "retained"):
            self.run_analysis()

    def test_too_few_active_frames_rejected(self):
        self.data["phases"][1]["end_ns"] = 1_100_000_000
        self.write()
        with self.assertRaisesRegex(EvidenceError, "need 30"):
            self.run_analysis()

    def test_reused_encoder_id_outside_lifetime_does_not_attribute(self):
        for r in self.rows["labels"]:
            r[0] += 10_000_000_000
        self.write()
        with self.assertRaisesRegex(EvidenceError, "encoder lifetime"):
            self.run_analysis()

    def test_altered_phase_source_rejected(self):
        self.source.write_text("changed source")
        with self.assertRaisesRegex(EvidenceError, "SHA-256 mismatch"):
            self.run_analysis()

    def test_repeated_scanout_is_not_new_frame(self):
        row = list(self.rows["swaps"][100])
        row[0] += 1_000_000
        row[2] += 99_000_000
        self.rows["swaps"].append(row)
        self.write()
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertEqual(result["attribution"]["candidate_display_swaps"], len(self.rows["swaps"]) - 1)

    def test_duplicate_swaps_rejected(self):
        self.rows["swaps"].append(list(self.rows["swaps"][100]))
        self.write()
        with self.assertRaisesRegex(EvidenceError, "Duplicate display swaps"):
            self.run_analysis()

    def test_unpresented_active_tail_cannot_return_green(self):
        self.rows["swaps"] = [r for r in self.rows["swaps"] if not 2_000_000_000 < r[0] <= 2_200_000_000]
        self.write()
        result, status = self.run_analysis()
        self.assertEqual(status, 2)
        self.assertFalse(result["boundary_20ms_check_passed"])
        self.assertGreater(result["phases"][1]["candidate_terminal_hold_lower_bound_ms"], 190)

    def test_xml_reference_resolution(self):
        path = self.folder / "reference.xml"
        path.write_text('<trace-query-result><node><schema name="test"><col><mnemonic>process</mnemonic></col></schema>'
                        '<row><process id="1"><pid id="2">123</pid></process></row>'
                        '<row><process ref="1"/></row></node></trace-query-result>')
        table = Table(path, "test", {"process"})
        self.assertEqual([table.pid(row) for row in table.rows], [123, 123])


if __name__ == "__main__":
    unittest.main()
