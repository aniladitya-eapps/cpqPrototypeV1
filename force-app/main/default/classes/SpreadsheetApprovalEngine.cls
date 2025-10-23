public class SpreadsheetApprovalEngine {

    // === Public DTOs ===
    public class EvaluationInput {
        @InvocableVariable(required=true) public Id QuoteId;
    }
    public class EvaluationOutput {
        @InvocableVariable public String Decision;       // AutoApprove / ManagerReview / Escalate
        @InvocableVariable public List<Id> ApproverIds;  // resolved target approver Ids
        @InvocableVariable public Integer SLA_Hours;
        @InvocableVariable public String RuleId;
        @InvocableVariable public String Notes;
    }

    // === Sheet rows ===
    public class RuleRow {
        public String RuleId;
        public Integer Priority;
        public Boolean Active;
        public String ObjectApi;   // e.g., 'Quote' or 'cg_Quote__c'
        public String FieldPath;   // e.g., 'DiscountPercent__c' or 'Opportunity.StageName'
        public String Operator;    // =, !=, >, >=, <, <=, IN, BETWEEN, CONTAINS, ...
        public String Value;       // e.g., '15..25' or 'Poor,Fair'
        public String AndGroup;    // usually '1'
        public String OrGroup;     // e.g., 'A'
    }
    public class OutcomeRow {
        public String RuleId;
        public String Decision;
        public String ApproverType;   // User, Role, Queue, FieldRef, None
        public String ApproverValue;  // Id/name/field path
        public Integer SLA_Hours;
        public String Notes;
    }

    // === In-memory structures ===
    public class CompiledRule {
        public String RuleId;
        public Integer Priority;
        public List<RuleGroup> groups = new List<RuleGroup>();  // OR of these
        public String Decision;
        public String ApproverType;
        public String ApproverValue;
        public Integer SLA_Hours;
        public String Notes;
    }
    public class RuleGroup {
        public List<Predicate> preds = new List<Predicate>();  // AND within a group
    }
    public class Predicate {
        public String fieldPath;
        public String op;
        public String rawValue;
    }

    // === PUBLIC: Flow entry point ===
    @InvocableMethod(label='Evaluate Quote Approval (Spreadsheet Rules)' description='Reads compiled rules and returns decision/approvers')
    public static List<EvaluationOutput> evaluateQuotes(List<EvaluationInput> inputs) {
        // Load rules (replace with Named Credential / CMDT in your org)
        String rulesCsv    = getRulesCsv();
        String outcomesCsv = getOutcomesCsv();

        List<RuleRow> ruleRows = parseRulesCsv(rulesCsv);
        Map<String,OutcomeRow> outcomeById = parseOutcomesCsv(outcomesCsv);

        List<CompiledRule> compiled = compile(ruleRows, outcomeById);

        // Preload records used by rules
        Set<Id> qIds = new Set<Id>();
        for (EvaluationInput i : inputs) if (i != null && i.QuoteId != null) qIds.add(i.QuoteId);
        Map<Id, SObject> quotes = preloadRecords(qIds, compiled);

        List<EvaluationOutput> res = new List<EvaluationOutput>();
        for (EvaluationInput i : inputs) {
            SObject q = (i != null) ? quotes.get(i.QuoteId) : null;
            EvaluationOutput out = evaluateOne(q, compiled);
            res.add(out);
        }
        return res;
    }

    // === Source providers moved to top-level static methods (Apex allows static only on top-level) ===
    private static String getRulesCsv()    { return SpreadsheetRulesFromFiles.readRulesCsv(); }
    private static String getOutcomesCsv() { return SpreadsheetRulesFromFiles.readOutcomesCsv(); }

    // === CSV parsing ===
    public static List<RuleRow> parseRulesCsv(String csv) {
        List<RuleRow> rows = new List<RuleRow>();
        if (String.isBlank(csv)) return rows;
        List<String> lines = csv.split('\n');
        if (lines.isEmpty()) return rows;
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i];
            if (String.isBlank(line)) continue;
            List<String> cols = splitCsvLine(line);
            if (cols.size() < 9) continue;
            RuleRow r = new RuleRow();
            r.RuleId     = cols[0].trim();
            r.Priority   = Integer.valueOf(cols[1]);
            r.Active     = cols[2].trim().toLowerCase() == 'true';
            r.ObjectApi  = cols[3].trim();
            r.FieldPath  = cols[4].trim();
            r.Operator   = cols[5].trim().toUpperCase();
            r.Value      = cols[6].trim();
            r.AndGroup   = cols[7].trim();
            r.OrGroup    = cols[8].trim();
            rows.add(r);
        }
        return rows;
    }
    public static Map<String,OutcomeRow> parseOutcomesCsv(String csv) {
        Map<String,OutcomeRow> outMap = new Map<String,OutcomeRow>();
        if (String.isBlank(csv)) return outMap;
        List<String> lines = csv.split('\n');
        if (lines.isEmpty()) return outMap;
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i];
            if (String.isBlank(line)) continue;
            List<String> cols = splitCsvLine(line);
            if (cols.size() < 6) continue;
            OutcomeRow o = new OutcomeRow();
            o.RuleId        = cols[0].trim();
            o.Decision      = cols[1].trim();
            o.ApproverType  = cols[2].trim();
            o.ApproverValue = cols[3].trim();
            o.SLA_Hours     = Integer.valueOf(cols[4]);
            o.Notes         = cols[5].trim();
            outMap.put(o.RuleId, o);
        }
        return outMap;
    }
    private static List<String> splitCsvLine(String line) {
        List<String> parts = new List<String>();
        String cur = '';
        Boolean inQ = false;
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i+1);
            if (ch == '"') inQ = !inQ;
            else if (ch == ',' && !inQ) { parts.add(cur); cur = ''; }
            else cur += ch;
        }
        parts.add(cur);
        return parts;
    }

    // === Compile rows → executable rules (OR-of-ANDs) ===
    public static List<CompiledRule> compile(List<RuleRow> rules, Map<String,OutcomeRow> outcomes) {
        Map<String, CompiledRule> byId = new Map<String, CompiledRule>();
        Map<String, Map<String, RuleGroup>> groupsByRule = new Map<String, Map<String, RuleGroup>>();


        for (RuleRow r : rules) {
            if (r == null || !r.Active) continue;
            OutcomeRow o = outcomes.get(r.RuleId);
            if (o == null) continue;

            CompiledRule cr = byId.get(r.RuleId);
            if (cr == null) {
                cr = new CompiledRule();
                cr.RuleId        = r.RuleId;
                cr.Priority      = r.Priority;
                cr.Decision      = o.Decision;
                cr.ApproverType  = o.ApproverType;
                cr.ApproverValue = o.ApproverValue;
                cr.SLA_Hours     = o.SLA_Hours;
                cr.Notes         = o.Notes;
                byId.put(r.RuleId, cr);
                groupsByRule.put(r.RuleId, new Map<String, RuleGroup>());
            }

            String gKey = (r.OrGroup == null ? '' : r.OrGroup) + '|' + (r.AndGroup == null ? '' : r.AndGroup);
            Map<String, RuleGroup> perRule = (Map<String, RuleGroup>)groupsByRule.get(r.RuleId);
            RuleGroup g = perRule.get(gKey);
            if (g == null) {
                g = new RuleGroup();
                perRule.put(gKey, g);
                cr.groups.add(g);
            }

            Predicate p = new Predicate();
            p.fieldPath = r.FieldPath;
            p.op        = r.Operator;
            p.rawValue  = r.Value;
            g.preds.add(p);
        }

        List<CompiledRule> compiled = new List<CompiledRule>(byId.values());
        compiled.sort(new ComparatorCompiled());
        return compiled;
    }
    public class ComparatorCompiled implements System.Comparator<CompiledRule> {
        public Integer compare(CompiledRule a, CompiledRule b) {
            Integer pa = (a == null || a.Priority == null) ? 2147483647 : a.Priority; // MAX_INT literal
            Integer pb = (b == null || b.Priority == null) ? 2147483647 : b.Priority; // MAX_INT literal
            if (pa == pb) return 0;
            return (pa < pb) ? -1 : 1;
        }
    }

    // === Data preload (dynamic SOQL, dynamic fields) ===
    private static Map<Id, SObject> preloadRecords(Set<Id> recIds, List<CompiledRule> compiled) {
        Map<Id, SObject> out = new Map<Id, SObject>();
        if (recIds == null || recIds.isEmpty()) return out;

        Id anyId = null;
        for (Id i : recIds) { anyId = i; break; }
        Schema.SObjectType sobType = anyId.getSObjectType();
        Schema.DescribeSObjectResult d = sobType.getDescribe();
        String apiName = d.getName();

        Set<String> selectPaths = new Set<String>{ 'Id', 'OwnerId', 'Owner.ManagerId' };
        for (CompiledRule cr : compiled)
            for (RuleGroup g : cr.groups)
                for (Predicate p : g.preds)
                    if (!String.isBlank(p.fieldPath)) selectPaths.add(p.fieldPath);

        String soql = 'SELECT ' + String.join(new List<String>(selectPaths), ', ')
                    + ' FROM ' + apiName
                    + ' WHERE Id IN :recIds';

        for (SObject row : Database.query(soql)) {
            out.put((Id)row.get('Id'), row);
        }
        return out;
    }

    // === Evaluate a single record ===
    private static EvaluationOutput evaluateOne(SObject q, List<CompiledRule> compiled) {
        if (q != null) {
            for (CompiledRule cr : compiled) {
                if (ruleMatches(cr, q)) {
                    EvaluationOutput out = new EvaluationOutput();
                    out.Decision    = cr.Decision;
                    out.SLA_Hours   = cr.SLA_Hours;
                    out.RuleId      = cr.RuleId;
                    out.Notes       = cr.Notes;
                    out.ApproverIds = resolveApprovers(cr, q);
                    return out;
                }
            }
        }
        // default
        EvaluationOutput def = new EvaluationOutput();
        def.Decision    = 'ManagerReview';
        List<Id> mgr = new List<Id>();
        Object ownerMgr = getFieldValue(q, 'Owner.ManagerId');
        if (ownerMgr instanceof Id) mgr.add((Id)ownerMgr);
        def.ApproverIds = mgr;
        def.SLA_Hours   = 24;
        def.RuleId      = 'DEFAULT';
        return def;
    }

    private static Boolean ruleMatches(CompiledRule cr, SObject q) {
        if (cr == null || q == null) return false;
        for (RuleGroup g : cr.groups) {
            Boolean all = true;
            for (Predicate p : g.preds)
                if (!predTrue(p, q)) { all = false; break; }
            if (all) return true;
        }
        return false;
    }

    // === Primitive predicate evaluator ===
    private static Boolean predTrue(Predicate p, SObject q) {
        Object val = getFieldValue(q, p.fieldPath);
        String op  = p.op;
        String rv  = p.rawValue;

        if (op == 'ISBLANK')     return (val == null || String.valueOf(val).trim() == '');
        if (op == 'ISNOTBLANK')  return !(val == null || String.valueOf(val).trim() == '');

        if (val != null && val instanceof Decimal) {
            Decimal dv = (Decimal) val;
            if (op == '=')  return dv == Decimal.valueOf(rv);
            if (op == '!=') return dv != Decimal.valueOf(rv);
            if (op == '>')  return dv >  Decimal.valueOf(rv);
            if (op == '>=') return dv >= Decimal.valueOf(rv);
            if (op == '<')  return dv <  Decimal.valueOf(rv);
            if (op == '<=') return dv <= Decimal.valueOf(rv);
            if (op == 'BETWEEN') {
                List<String> parts = rv.split('\\.\\.');
                if (parts.size() != 2) return false;
                Decimal lo = Decimal.valueOf(parts[0]);
                Decimal hi = Decimal.valueOf(parts[1]);
                return dv >= lo && dv <= hi;
            }
        }

        String sv = (val == null ? '' : String.valueOf(val));
        if (op == '=')           return sv == rv;
        if (op == '!=')          return sv != rv;
        if (op == 'CONTAINS')    return sv.contains(rv);
        if (op == 'STARTS_WITH') return sv.startsWith(rv);
        if (op == 'ENDS_WITH')   return sv.endsWith(rv);
        if (op == 'IN') {
            Set<String> setv = new Set<String>();
            for (String s : rv.split('\\s*,\\s*')) setv.add(s);
            return setv.contains(sv);
        }
        return false;
    }

    // Supports nested paths: "Opportunity.StageName", "Account.CreditScoreBucket__c"
    private static Object getFieldValue(SObject root, String path) {
        if (root == null || String.isBlank(path)) return null;
        SObject cur = root;
        List<String> parts = path.split('\\.');
        for (Integer i = 0; i < parts.size(); i++) {
            String key = parts[i];
            if (i == parts.size() - 1) return cur.get(key);
            cur = (SObject) cur.getSObject(key);
            if (cur == null) return null;
        }
        return null;
    }

    // === Helper: resolve approvers by outcome ===
    private static List<Id> resolveApprovers(CompiledRule cr, SObject q) {
        List<Id> ids = new List<Id>();
        String t = (cr.ApproverType == null ? '' : cr.ApproverType.toLowerCase());
        String v = cr.ApproverValue;

        if (t == '' || t == 'none') return ids;

        if (t == 'user') {
            if (v != null && v.startsWith('005')) ids.add((Id) v);
        } else if (t == 'role') {
            for (User u : [SELECT Id FROM User WHERE UserRole.DeveloperName = :v AND IsActive = true]) {
                ids.add(u.Id);
            }
        } else if (t == 'queue') {
            Group qg = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :v LIMIT 1];
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :qg.Id]) {
                ids.add(gm.UserOrGroupId);
            }
        } else if (t == 'fieldref') {
            Object o = getFieldValue(q, v);
            if (o instanceof Id) ids.add((Id) o);
        }
        return ids;
    }
}
